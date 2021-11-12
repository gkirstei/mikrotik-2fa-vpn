# OnUp script
{
    :local localAddr $"local-address";
    :local remoteAddr $"remote-address";
    :local callerId $"caller-id";
    :local calledId $"called-id";
    :local interfaceName [/interface get $interface name];

    :log info "$user (srcIp=$callerId, dstIp=$calledId) connected: was given $remoteAddr IP (GW $localAddr) and assigned to $interfaceName interface";

    # Block routed traffic through router
    # Adjust according to your firewall setup
    # Remember to also change removal rules below
    # This is not needed if traffic is blocked for all addreses in dynamic address_list vpn_pending
    # /ip firewall filter add action=reject chain=forward in-interface="$interfaceName" reject-with=icmp-admin-prohibited comment="auto-vpnauth-rule-$user-$interfaceName"

    /system script run "JParseFunctions";
    :global JSONUnload;

    /system script run "NotakeyFunctions";
    :global NtkAuthRequest;
    :global NtkWaitFor;
    :global NtkUnload;

    # Change values below to match your Notakey installation
    # ntkHost - https hostname of Notakey Authentication Server (NtkAS)
    :local ntkHost "demo.notakey.com";
    # ntkAccessId - service ID of NtkAS, can be seen in settings
    :local ntkAccessId "12345645-b32b-4788-a00d-251cd7dc9a03";
    # Custom message in authentication request
    :local authDescMsg "Log in as $user from $callerId\?";

    :local ntkAuthUuid ([$NtkAuthRequest host=$ntkHost accessId=$ntkAccessId authUser=$user authTitle="VPN connection" authDesc=$authDescMsg]);

     # Terminates ppp connection in case of the script error
     :if ($ntkAuthUuid = ";;ERROR Notakey Auth request send error") do { 
     :log error  "Can't connect to the Notakey appliance!";
      /ppp active remove [/ppp active find name=$user];
      }
        
    :if ([$NtkWaitFor uuid=$ntkAuthUuid host=$ntkHost accessId=$ntkAccessId]) do={
        :put "All cool, we are letting you in";
        # Remove blocking rule after successful 2FA autehntication
        # /ip firewall filter remove [/ip firewall filter find where comment="auto-vpnauth-rule-$user-$interfaceName"]
        :log inf "New VPN connection from: $user !";
    } else={
        :put "2FA check failed (due to expiry or denied)";
        # Terminate active vpn connection
        /ppp active remove [/ppp active find name=$user]
                            
        # We have an unsuccessful authentication attempt. It is possible that someone has your VPN password!
        #/tool e-mail send to="noc@example.com" subject="VPN 2FA authentication failure for user $user from IP $callerId";
    }

    $NtkUnload
    $JSONUnload
}

# OnDown script
{
    # In case 2FA is not approved we need to clean up
    # filter entry to avoid filling the filter table up.

    :local localAddr $"local-address";
    :local remoteAddr $"remote-address";
    :local callerId $"caller-id";
    :local calledId $"called-id";
    :local interfaceName [/interface get $interface name];

    :log info "$user (srcIp=$callerId, dstIp=$calledId) logged out: was given $remoteAddr IP (GW $localAddr)";

    /ip firewall filter remove [/ip firewall filter find where comment="auto-vpnauth-rule-$user-$interfaceName"]
}
