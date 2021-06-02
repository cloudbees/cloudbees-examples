Install Chart to update nfs permissions. 

   This chart creates Persistent Volume and Persistent Volume claim with given nfs host and nfs path with storage.
   Updated User/Group/Mode permissions for NFS . This chart runs a job which updates permission for NFS using command 
   chown and chmod

##  Common Configuration

The following table lists the configurable parameters with their default values.

|             Parameter   |                     Description                                                 |  Default Value  |
|-------------------------|---------------------------------------------------------------------------------|-----------------|
| `permissions.user`      |  Filesystem user for permission updates using command `chown user:group /path`  | None            |                                                 
| `permissions.group`     |  Filesystem group for permission updates using command `chown user:group /path` | None            |                                                  
| `permissions.mode`      |  Filesystem accessMode for permission updates using command `chmod 770 /path`   |  770            |                                                               
| `nfs.host`              |  Required NFS Host.IP or DNS. Append port if not using default NFS port  `2049` | None            |                                                      
| `nfs.path`              |  NFS path  to mount. e.g /                                                      |     /           |                                                      
| `nfs.storage`           |  Storage size to mount for nfs. e.g 5Gi                                         |   5Gi           |                                                      
| `nfs.accessMode`        |  Filesystem accessMode to create PV . ReadWriteOnce, ReadWriteMany              |   ReadWriteMany |                                                      
-------------------------------------------------------------------------------------------------------------------------------


helm install your-release-name nfs-permissions -f values-input.yaml

e.g values-input.yaml
```
permissions:
  mode: 770

nfs:
  storage: 5Gi
  host: "10.141.161.42"
  path: "/ocp"
  accessMode: ReadWriteMany

```