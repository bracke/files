--  Explicit inspection and disposition of retained replacement payloads.
with Files.Types;

package Files.Recovery_CLI is
   --  Handle a recovery command when present. Returns False for normal GUI
   --  arguments. Commands are --list-recoveries [DIR], --recover PAYLOAD, and
   --  --discard-recovery PAYLOAD. With no DIR, the list uses the global index.
   --  @return True when a recovery command was recognized and handled.
   function Run_If_Requested return Boolean;

   --  Run_If_Requested over Arguments instead of the command line, without
   --  touching the process exit status.
   --  @param Arguments The arguments, the command first.
   --  @param Failed True when a recognized command failed.
   --  @return True when a recovery command was recognized and handled.
   function Run
     (Arguments : Files.Types.String_Vectors.Vector;
      Failed    : out Boolean) return Boolean;
end Files.Recovery_CLI;
