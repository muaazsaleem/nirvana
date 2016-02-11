#!/bin/bash

# Director Boot stage 1
director_bootup_stage1_info=".*: Broker and SM on director <.*> <.*> got initialized successfully \(took .* seconds\)"
director_bootup_stage1_error=".*: SMLite initialization failed on <.*> <.*>. Last good known step is 'Broker is ready'. Next expected step is 'SM is ready'."

# Director Boot stage 2
director_bootup_stage2_info=".*: Service directory \(service_directory_.*\) on director <.*> <.*> got initialized successfully \(took .* seconds\). All Director services are up and active."
director_bootup_stage2_error=".*: Service directory .* on director <.*> <.*> failed to initialize. Last good known state is 'CM topology load is complete'. Next expected state is 'SD INIT completed.'."

# Edge Bootup
edge_bootup_info=".*: Compute node on <.*> <.*> got initialized successfully \(took .* seconds\)"
edge_bootup_error=".*: Initialization of compute node on <.*> <.*> failed. Last good known step is '.*'. Next expected step is '.*'"

# Edge Reconnect
edge_reconnect_info=".*: Compute node on <.*> <.*> got reconnected to director cluster \(took .* seconds\)."
edge_reconnect_error=".*: Reconnection of compute node on <.*> <.*> to director cluster failed. Last good known step is '.*'. Next expected step is '.*'"

# Director exit
director_exit_info=""
director_exit_error=""
director_exit_warn=".*: Director <.*> <.*> exited with reason '.*'."

# crash_relaunch_success
crash_relaunch_success_info=".*: Process '\S*' \(pgname '\S*', ip_pid '\S*' domain '\S*' vnf_name '\S*'\) exited with reason \S* and got relaunched successfully with ip_pid '\S+'. The recovery took \S* seconds"
# crash_relaunch_failure
crash_relaunch_failure_error=".*: Process '\S*' \(pgname '\S*', ip_pid '\S*' domain '\S*' vnf_name '\S*'\) exited with reason \S* and failed to restart.  Last good known state is '.*'. Next expected state is '.*'."

# ifup success
ifup_success_info=".*: Interface \(name:.*, type:.*, mac:.*, uuid:.*\) successfully attached to edge \S+ <.*> <.*> \(took .* seconds\)"
ifup_failure_error=".*: Interface \(name:\S*, type:access_vm, mac:\S*, uuid:\S*\) failed to attach to edge <\S*> <.*> Last good known state is 'ifup latency'. Next expected state is 'ifup completion'. Transaction id: \S*"

# topology load from cdb
topology_load_cdb_info=".*: VND .* created successfully .* via CDB"
topology_load_cdb_error=".*: VND .* creation failed. Last good known state is '.*'. Next expected state is '.*'. Transaction id: \S*"
