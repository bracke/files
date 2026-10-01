--  Explicit inspection and disposition of retained replacement payloads.
package Files.Recovery_CLI is
   --  Handle a recovery command when present. Returns False for normal GUI
   --  arguments. Commands are --list-recoveries DIR, --recover PAYLOAD, and
   --  --discard-recovery PAYLOAD.
   --  @return True when a recovery command was recognized and handled.
   function Run_If_Requested return Boolean;
end Files.Recovery_CLI;
