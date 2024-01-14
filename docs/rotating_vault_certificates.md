# Rotating Vault Certificates

This module uses certs that are either local (self-signed) or via Vault (depending on the Vault PKI configuration). Vault depends on certificate for mTLS between nodes in a cluster--these are normally generated when installing vault via package manager, but for a multi-node cluster, they have to be the same across all nodes.

This module also uses the same set of certificates for TLS via the load balancer.

Certificates may need to be rotated manually in two main scenarios:

1. Creating the first vault cluster that will run PKI, and re-running this module to be self-referencial for issuing certs (The vault cluster created by this module will issue certs for itself).
2. Certificates expire, and new nodes cannot join the cluster.

The process outlined below incurs almost zero downtime, and is relatively simple to complete with basic linux and Vault knowledge.

## Certificate Management

After bootstrapping the initial cluster and configuring it as a PKI, simply recreating the cluster will cause issues as it would delete the cluster that contains the PKI. Instead, it is possible to simple rotate the certificates on the current nodes to use certificates issued by Vault. This will allow Vault to issue certs for itself without losing data or the PKI configuration.

The process is largely simple:

1. Issue new certificates
2. Log into the nodes and replace the certs
3. Restart the nodes in a specific order
4. Re-run the Terraform

_**This process incurs minimal downtime if done correctly (a few seconds), however it is recommended to call a maintenance window and prevent new data from being written to vault with a security group rule modification. This way, if there are any issues, the snapshot taken before the cert rotation can be restored without any data loss. If we do not call a maintenance window, new data may be written to vault that is not captured in the snapshot, resulting in data loss if we have to restore.**_

1. Before taking any action, log into AWS and disable the automated autoscaling group actions by [suspending the processes](https://docs.aws.amazon.com/autoscaling/ec2/userguide/as-suspend-resume-processes.html). With the processes suspended, failed health checks due to the rotation process will not cause node replacement.
2. Run `terraform apply` in targeted mode to create the new certs. They will also be loaded into the launch template, but since the ASG is frozen, no new nodes will be created due to instance replacement strategy.

    ```console
    tf apply \
      -target 'module.vault_cluster.vault_pki_secret_backend_cert.default[0]' \
      -target 'module.vault_cluster.aws_s3_object.user_data' \
      -target 'module.vault_cluster.aws_launch_template.default'
    ```

3. Using outputs, gather the newly generated cert, key, and issuing chain. Due to multiline outputs for sensitive values, it may be required to format the certificates before adding them to the vault nodes.

    ```console
    terraform output cert_data
    ```

4. Log in to each of the vault nodes at the same time, using multiple terminal windows, and elevate to root to simplify things.
5. Log into Vault from the cli, identify the leader node (`vault status` will work but requires running on all nodes, the `operator` command below can be run from anywhere), and take a snapshot from the leader node and upload to S3. If anything goes wrong, this snapshot can be used for restore.

    ```console
    vault login -method=oidc username=<username>
    vault operator raft list-peers
    # From the leader node
    DATE=$(date +%Y-%m-%d-%H-%M-%S)
    vault operator raft snapshot save "${DATE}.snap"
    aws s3 cp "${DATE}.snap" s3://<backup bucket>/migrations/
    ```

6. With the snapshot saved, replace the contents of the cert and key files on each of the vault nodes. _**WARNING!! DO NOT DELETE THE FILES! Edit them place--the permissions are very important for Vault to function properly**_

    ```console
    vi /opt/vault/tls/vault-cert.pem # Put data from outputs in step 3
    vi /opt/vault/tls/vault-ca.pem   # Put data from outputs in step 3
    vi /opt/vault/tls/vault-key.pem  # Put data from outputs in step 3
    ```

7. Once all the files are updated, make sure the leader node has been properly identified. Running `vault status` from the leader node and ensuring the output says `active` is a good confirmation. During the restart, Vault will not have enough nodes to properly vote and elect a new leader, so the order is important.

8. Follow the below steps in order, taking note of which nodes (leader or standby). Make sure to perform them in quick succession, which can help avoid any leader election issues.
    1. On the _**STANDBY NODES:**_
        
        ```console
        systemctl stop vault 
        ```
    
    2. On the _**ACTIVE/LEADER NODE:**_
    
        ```console
        systemctl restart vault 
        ```
    
    3. Wait 3-5 seconds
    4. On the _**STANDBY NODES:**_

        ```console
        systemctl start vault 
        ```

9. Validate the health of the cluster nodes with `vault status`. The output should look close to the following:

        Key                      Value
        ---                      -----
        Recovery Seal Type       shamir
        Initialized              true
        Sealed                   false
        Total Recovery Shares    5
        Threshold                3
        Version                  1.15.4
        Build Date               2023-12-04T17:45:28Z 
        Storage Type             raft
        Cluster Name             vault-cluster-<short sha>
        Cluster ID               <guid> 
        HA Enabled               true
        HA Cluster               https://10.42.42.42:8201
        HA Mode                  standby | active
        Active Node Address      https://<vault fqdn>
        Raft Committed Index     123456
        Raft Applied Index       123456

In this case, the important things to look for are:
    - Recovery Seal Type is `shamir`
    - Initialized is `true`
    - Sealed is `false`
    - HA mode is `active` or `standby`.  The active node should still report as the active node.  If it does not, ensure that 1 node is active and the rest of the nodes are standby.

If anything went wrong and the node could not properly start or unseal vault, the output will look much different, and will likely show "Sealed = true". If that is the case, wait a few seconds to see if a leader election occurs and fixes the issue, or proceed to the troubleshooting steps below.

10. With vault healthy, run `terraform apply` on the state again. Terraform will undo the autoscaling group locks from the start of this guide and update the ACM cert to use the new certificate, along with an instance refresh. The new nodes will come up with user data that has the new certificates, and should have no issue joining the cluster.
11. Closely monitor the node replacement from the AWS console, logging into the new nodes as they start and watching the `/var/log/user-data.log` file to ensure they join the cluster successfully. It is also a good idea to keep an eye on the Vault UI to ensure stability.
12. Congratulations! The certificates have been rotated.

# Troubleshooting

Always take a snapshot before any action like rotating certificates, as in the event of a catastrophic failure the data can be restored from this snapshot.

Also always remember to check the vault operator logs with `journalctl -u vault` as they can provide helpful debugging information.

The `log_level` line in the server config file (`/etc/vault/vault.hcl`) can be changed to `trace` or` `debug` to provide more verbose logging.

**Vault is sealed**

If vault is sealed after rotating the certificates, and it does not unseal after a few seconds, a few things may help:
1. Restart vault again with `systemctl restart vault`. If that does not fix the issue, check the logs for pointers
2. Validate the file permissions on the cert, key, and chain. They should be owned by `vault:vault` or `root:vault` and the permissions should be `0644` for the cert and chain, and `0640` for the key.
3. Validate the cert/key contents, as sometimes copy/pasting can leave unwanted artifacts.
4. If all the files anf file permissions are correct and another vault restart does not help, turn to the logs for help.

**No leader - all nodes are standby**

1. If there is no leader node, restart vault on all nodes and wait a few seconds to see if a new leader election occurs. If it does not, a [Lost Quorum Recovery](https://developer.hashicorp.com/vault/tutorials/raft/raft-lost-quorum) can help.
2. Follow the steps in the linked guide. If they do not work, a lost quorum recovery can be done just on the leader node, essentially turning the cluster into a one node cluster for long enough to create a leader, and the standby nodes can be restarted--this usually works. To perform this, follow the steps as linked but instead of creating a `raft.json` file consisting of all nodes, create one for JUST the leader node. Since all the nodes are `standby` at this point, you can identify the most likely leader by checking the file size of `raft.db`, usually located in `${RAFT_STORAGE_PATH}/raft/raft.db` (`/opt/vault/data/raft/raft.db` in this module). Whichever file is largest is likely your last leader, and can be used for a single node lost quorum recovery. Stop the vault service on the other nodes, and perform the recovery. Restart vault on the other nodes, and vault may recover.

When all else fails, any remaining issues can be resolved by restoring the snapshot taken before the cert rotation, and trying again.
