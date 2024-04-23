# Backupchain

This tool is designed to quickly and easily sync multiple folders and drives together. If you find yourself running rsync or other backups between different locations a lot, this tool can simplify that process.

### How it works

You create a YAML file that lists the locations that you will backup to and from (hosts, folders, and disks) and how you want the backups to be executed. Backupchain can then use this config to write and orchestrate rsync to get a complex sync job done automatically.

### Cool stuff it supports

* Shiftsync (A snapshot-like backup style)
* Parallelization
* Auto-mounting of disks
* Auto-fsck
* Disk verification
* Linux and MacOS (sorry Windows folks... but you're welcome to contribute)

## Getting Started

### Installation

```shell
curl -so /usr/local/bin/backupchain https://raw.githubusercontent.com/akhoury6/backupchain/master/portable/backupchain-portable.rb
chmod 0555 /usr/local/bin/backupchain
```

### Your first config
Backupchain can generate an example config to get you started. This might look like a lot for now, but if you scroll down past it we'll walk though creating one step-by-step.

```shell
backupchain -i
vi backupchain.yaml
```

Click [here](#complete-example) to see the generated config, or continue for step-by-step instructions on how to build one yourself.

## Config Building Tutorial

The config is divided into three sections:

```yaml
locations:
execution_tree:
rsync_defaults:
```

The `locations` section describes the sources and targets of the syncs. These are essentially folders, disks, and SSH details in case any of them are on a remote server.

The `execution_tree` section organizes the locations into trees and describes the transfers that should happen between them. Locations can be used more than once, as both sources and targets of a sync.

The `rsync_defaults` section sets default CLI parameters to be passed to `rsync`, which is the sync back-end that is used. Note that backupchain automatically ignores system-specific files like `.DS_Store` files on MacOS and `lost+found` on Linux so those don't need to be entered. If you are unsure of what options to use, a good starting point is to use `-avhz` and `--delete-before`. You do not have to include leading dashes except if putting multiple short (one-letter) options into the same entry, but you can if you'd like.

### Building an example config

Let's use a typical power-user scenario as an starting point:

* You have a users on your local system and want to back up your home folders located under `/home/user`
* You also have a local storage drive with lots of files on it for backup
* You have a local server for backups, with internet access via port forwarding
* You hvae an offsite server for backups
* You have your server's SSH credentials configured in your ~/.ssh/config
* You want to run backups to the two servers in parallel to speed up the process

### Locations declarations
Let's start by declaring these locations in the config:

```yaml
locations:
  Home Folder:
    root: /home/user
    highlight_color: green
  Storage Drive:
    root: /mnt/storage
    disk: true
    highlight_color: yellow
  Local Server:
    root: /mnt/bigarray
    ssh:
      local:
        addr: 192.168.1.10 # This can map to an IP address, DNS address, or a Host entry in your ~/.ssh/config
      remote:
        addr: my.public.dns.com
        port: 2222
    disk: true
    highlight_color: blue
  Remote Server:
    root: /mnt/lotsofroom
    ssh:
      remote:
        addr: some.lucky.dns.address.com
        port: 2345
    disk: true
    highlight_color: magenta
```

The highlight colors are not required, but they will make the output prettier and easier to read when running it.

### Execution Tree
Now let's add the execution trees. First let's add the home folder backups:

```yaml
execution_tree:
  - location: Home Folder
    source_folder: /
    outgoing:
      targets:
        - location: Storage Drive
          incoming:
            dest_folder: /home/user
```

Note that the folders here are relative to the `root` set in the `locations` declarations above. Since the root of the Storage Drive is set to `/mnt/storage`, the full paths of the backup targets will be `/mnt/storage/home/user1` and `/mnt/storage/home/user2`.

Now that we have the data copied to the Storage Drive, let's sync the entire Storage drive with the local server. Building off of the above, this is how that looks:

```yaml
execution_tree:
  - location: Home Folder
    outgoing:
      source_folder: /
      targets:
        - location: Storage Drive
          incoming:
            dest_folder: /home/user
  - location: Storage Drive                # The new part starts here
    outgoing:
      source_folder: /
      targets:
        - location: Local Server           # We are copying from root to root so
        - location: Remote Server          # the defaults are good enough
```

### Failovers
Then we also want to account for failures. Let's say your local drive failed for whatever reason, or maybe its an external drive that isn't attached, but you still want your home folders to get backed up to the two servers. We can set the two servers as failover locations, which will only get executed if the local storage drive is missing:

```yaml
  - location: Home Folder
    outgoing:
      source_folder: /
      targets:
        - location: Storage Drive
          incoming:
            dest_folder: /home/user
      failovers:                         # Failovers only get used if there are no available locations under `targets`
        - location: Local Server
            incoming:
              dest_folder: /home/user
        - location: Remote Server
            incoming:
              dest_folder: /home/user
```

### Rsync options
Lastly, we need to set some rsync options. We want to

* Set some sane global defaults
* Skip some folders that don't need to be backed up
* Use compression when transferring to the remote server to speed it up

So we start with the global options:
```yaml
rsync_defaults:
  - archive
  - verbose
  - stats
  - delete-before
```

Then we set some options for the home folder by placing them under the `outgoing` clause, and server-specific options under the `incoming` clause

```yaml
  - location: Home Folder
    outgoing:
      source_folder: /
      rsync_options_merge:       # We skip some folders for all outgoing transfers
        - exclude="Downloads"
        - exclude="Virtual Machines.vmwarevm"
      targets:
        - location: Storage Drive
          incoming:
            dest_folder: /home/user
      failovers:
        - location: Local Server
            incoming:
              dest_folder: /home/user
        - location: Remote Server
            incoming:
              dest_folder: /home/user
              rsync_options_merge:    # We enable compression
                - compress
```

### Finished example
Now we have a fully working config. Here's what it all looks like put together:

```yaml
locations:
  Home Folder:
    root: /home/user
    highlight_color: green
  Storage Drive:
    root: /mnt/storage
    disk: true
    highlight_color: yellow
  Local Server:
    root: /mnt/bigarray
    ssh:
      local:
        addr: 192.168.1.10
      remote:
        addr: my.public.dns.com
        port: 2222
    disk: true
    highlight_color: blue
  Remote Server:
    root: /mnt/lotsofroom
    ssh:
      remote:
        addr: some.lucky.dns.address.com
        port: 2345
    disk: true
    highlight_color: magenta
execution_tree:
  - location: Home Folder
    outgoing:
      source_folder: /
      rsync_options_merge:
        - exclude="Downloads"
        - exclude="Virtual Machines.vmwarevm"
      targets:
        - location: Storage Drive
          incoming:
            dest_folder: /home/user
      failovers:
        - location: Local Server
            incoming:
              dest_folder: /home/user
        - location: Remote Server
            incoming:
              dest_folder: /home/user
              rsync_options_merge: [compress]
  - location: Storage Drive
    outgoing:
      targets:
        - location: Local Server
        - location: Remote Server
            incoming:
              rsync_options_merge: [compress]
rsync_defaults:
  - archive
  - verbose
  - stats
  - delete-before
```


## Advanced Concepts

### Nested Trees
The execution tree is a recursive structure, meaning you can nest your syncs as deep as you'd like to go. You can rewrite the above example like this:

```yaml
execution_tree:
  - location: Home Folder
    outgoing:
      source_folder: /
      rsync_options_merge:
        - exclude="Downloads"
        - exclude="Virtual Machines.vmwarevm"
      targets:
        - location: Storage Drive
          incoming:
            dest_folder: /home/user
          outgoing:
            source_folder: /
            targets:
              - location: Local Server
              - location: Remote Server
                incoming:
                  rsync_options_merge: [compress]
      failovers:
        - location: Local Server
            incoming:
              dest_folder: /home/user
        - location: Remote Server
            incoming:
              dest_folder: /home/user
              rsync_options_merge: [compress]
```

### Execution Groups (Parallelization)
By default, the declared trees execute sequentially in the order that they are declared. However, you can put them in numbered groups to run in parallel. All the trees in group 0 will run together, followed by all of the trees in group 1, and so on. This give you even more flexibility to parallelize operations.

If the config is mixed, in that some locations have execution groups and others don't, the ones that don't will be run _after_ all of the execution groups have completed.

```yaml
execution_tree:
  - location: Home Folder
    execution_group: 0
    outgoing:
      targets:
        - location: Storage Drive
          incoming:
            dest_folder: /home/user
  - location: User2 Home Folder
    execution_group: 0
    outgoing:
      targets:
        - location: Storage Drive
          incoming:
            dest_folder: /home/user2
  - location: Storage Drive
    execution_group: 1
    outgoing:
      targets:
        - location: Local Server
        - location: Remote Server
```

Strict locking of resources is used to ensure that multiple trees can't act on the same locations at the same time, however, you may still end up with inconsistent data if you aren't careful.

### Parallelize keyword (More Parallelization)
We can also instruct it to sync with all of the targets simultaneously. Note that if all of the targets are missing and it has to back up to the failovers, the failovers will _not_ run in parallel so as to be cautious about data safety.

```yaml
execution_tree:
  - location: Storage Drive
    outgoing:
      source_folder: /
      parallelize: true          # We just add this line in
      targets:
        - location: Local Server
        - location: Remote Server
```

### Remote execution
Backupchain is not limited to syncing between the local system and remote servers, or vice versa. It can also do remote-to-remote syncs as well via SSH. This happens transparently to the user.

```yaml
locations:
  Local Server:
    root: /mnt/bigarray
    ssh:
      local:
        addr: 192.168.1.10
    disk: true
    highlight_color: blue
  Remote Server:
    root: /mnt/lotsofroom
    ssh:
      remote:
        addr: some.lucky.dns.address.com
        port: 2345
    disk: true
    highlight_color: magenta
execution_tree:
  - location: Local Server
    outgoing:
      targets:
        - location: Remote Server
```

### Drive/Parition Verification
If you supply backupchain with the UUID of a parition you are expecting to hold the `root` of the location, it can verify that the path you have given is indeed on the disk you are expecting it to be on. This helps when working with external drives, and/or bad actors that may try mounting a different drive there to get your data.

To get your partition UUID, run the following:

```shell
MacOS: diskutil info "/dev/disk#s#" | grep "Volume UUID"
Linux: blkid "/dev/disk#s#"
```

And here it is in a config:

```yaml
locations:
  Storage Drive:
    root: /mnt/storage
    disk:
      uuid: 6efbf597-9004-47ee-9062-50e733c72d2a
    highlight_color: yellow
```

### Automounting
To go along with the uuid identification, backupchain can automatically mount that drive at the root directory.

```yaml
locations:
  Storage Drive:
    root: /mnt/storage
    disk:
      automount: true
      uuid: 6efbf597-9004-47ee-9062-50e733c72d2a
    highlight_color: yellow
```

### Auto-fsck
Just as the name implies, backupchain can automatically run fsck on a disk before syncing to or from it. However, since too many fsck's can shorten a drive's lifespan, enabling this requires each location to have a flag set in the config, _and_ for a command line parameter to be passed.

```yaml
locations:
  Storage Drive:
    root: /mnt/storage
    disk:
      can_fsck: true
      automount: true
      uuid: 6efbf597-9004-47ee-9062-50e733c72d2a
    highlight_color: yellow
```

```shell
backupchain -f
backupchain --fsck
backupchain --fsck-only="Storage Drive" --fsck-only="Local Server"
```

### Shiftsync
Shiftsync is a mode that allows you to maintain different versions of syncs. Rather than syncing all locations in a tree together, it traverses the tree backwards so that each location stores a different version of the data.

For example, let's say you have the following nested config:

```yaml
execution_tree:
  - location: Storage Drive
    outgoing:
      exec_mode: shiftsync
      targets:
        - location: Local Server
          outgoing:
            targets:
              - location: Remote Server
```

In the default `fullsync` mode, first the Storage drive will sync to the Local server, then the local server will sync to the Remote server. This turns both servers into replicas of Storage Drive.

In `shiftsync` mode, these are executed backwards. First the Local server is sync'd to the Remote server, then the Storage drive is sync'd to the Local server. This means that the Local server will contain the latest version of your backup, while the Remote server will remain one version behind.

This can be helpful to protect against accidental file deletions or modifications, or other general file corruption causing you to lose your data.

## Complete Example

This is the skeleton config file, as generated by running `backupchain -i`

<!-- BEGIN SKELFILE -->
```yaml
---
locations:                          # (Required) Define the locations that the tool should back up to and/or from
  Home Folder:
    root: /home/myuser
    highlight_color: green
  Storage Drive:
    root: /mnt/storage
    disk: true                      # (Optional) Flag this target as a removable hard drive for more accurate availability detection. Can also automatically verify that the correct parition UUID is mounted (syntax below)
    highlight_color: yellow
  Backup Server:                    # (Required) Name of the target
    root: /mnt/backup               # (Required) Path of the backup root
    ssh:                            # (Optional) If the SSH block is defined, the target is treated as a remote server
      credentials:                  #    SSH Credentials. You may skip these if they are defined in ~/.ssh/config
        user: example
        keyfile: ~/.ssh/id_rsa
      local:                        # The settings for reaching this server on the local network. If both
        addr: 192.168.1.10          #     local and remote are defined, the local connection will be attempted
        port: 22                    #     first and the remote will be used as a fallback. At least one
      remote:                       #     of these two must be defined if using SSH.
        addr: my.public.dns.com
        port: 22
    disk:                           # (Optional) Designate a drive as removable and specify a partition to mount at the given root. This may also simply be set to 'true' or 'false' to simply check that a disk is present
      automount: false              #     Automatically mount the partition if it is found. Set to false to verify only. Defaults fo 'false'
      uuid: 6efbf597-9004-47ee-9062-50e733c72d2a  # Volume UUID that is expected at the mountpoint. The Volume UUID can be found by running `sudo blkid /dev/<device>` on linux or `diskutil info /dev/<device>` on MacOS. Setting this value will ensure that the expected volume is the one mounted, and also be used for automounting
      can_fsck: false               #     If this is set to true, then when the script is run with the `--fsck` command line parameter, an fsck check will be performed before any backups take place
    highlight_color: magenta        # (Optional) Highlight this target in the command output. For color options, see: https://github.com/fazibear/colorize/blob/8dcce6dac27855e1ac23ad5383ba56e25447e783/lib/colorize/class_methods.rb#L5
execution_tree:                     # (Required) Describe the execution chain, defining how the backups are to occur. This is a recursive tree. Each target/failover node is identical to its parent
  - location: Home folder           # (Required) Set the location for the node
    execution_group: 0              #    (Optional) Tree roots can be executed in parallel by grouping them together into 'execution groups'. Lower numbered groups will be executed first. Any roots that don't have one specified will be run sequentially at the end. Only valid on the root node.
    outgoing:                       #    (Required) These are parameters to be applied to the outgoing sync (where this location is the source)
      exec_mode: fullsync           #        Options are "fullsync" (default) and "shiftsync". Fullsync will keep all nested targets identical. Shiftsync will perform the backups in reverse, keeping different "versions" of the data
      parallelize: true             #        Run all outgoing backups from this node in parallel (multi-threaded). Access to drives is thread-safe and controlled with locks, but a race condition can still be created if the backup order is sensitive.
      source_folder: /              #        Subfolder relative to the Location root defined above
      rsync_options_merge: ~        #        Additional options to be used with rsync for outgoing transfers
      targets:                      #    (Required) 'targets' is the list of the primary backup targets. These is either an array of strings (if no options need to be set)
        - location: Storage Drive   #        or of objects as shown here. This is useful to chain backups from one location to the next
          incoming:                 #    These are parameters for the incoming transfer from the parent location
            source_folder_override: /   # This does exactly what it says. Useful when trying to back up different folders of the same drive to different locations in parallel
            dest_folder: /home      #        Sets the destination folder for the backup coming from the parent, relative to the location root
            rsync_options_merge: ~              #  The options specified here will be merged with the defaults set previously
            rsync_options_override: ~           #  The options specified here will override the defaults set previously. If this is set, both the defaults and the merged options (specified above) are ignored
          outgoing:
            targets:
              - Backup Server       #        This could also be another nested object like it's parent, but in this case we don't need to set any options
      failovers:                    #    (Optional) Failover servers are backed up to in case the primary target is not available. The format is identical to the targets
        - location: Backup Server
          dest_folder: /home
rsync_defaults:                     # (Optional) Define the default command-line options to be passed to rsync, before any per-target settings are specified (shown above)
  - -avhz                           #     Defaults to having no options set
  - delete-before                   #     Adding in --dry-run here for testing is not necessary if passing in the command-line paramter -d (--dry-run) when running
```
<!-- END SKELFILE -->