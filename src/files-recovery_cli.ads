--  Explicit inspection and disposition of retained replacement payloads.
with Files.Types;

package Files.Recovery_CLI is
   --  Handle a recovery command when present. Returns False for normal GUI
   --  arguments. Commands are --list-recoveries [DIR], --recover PAYLOAD, and
   --  --discard-recovery PAYLOAD. With no DIR, the list uses the global index.
   --  @return True when a recovery command was recognized and handled.
   function Run_If_Requested return Boolean;

private

   --  Run_If_Requested over Arguments instead of the command line, without
   --  touching the process exit status.
   --  @param Arguments The arguments, the command first.
   --  @param Failed True when a recognized command failed.
   --  @return True when a recovery command was recognized and handled.
   function Run
     (Arguments : Files.Types.String_Vectors.Vector;
      Failed    : out Boolean) return Boolean;

   --  Text as --list-recoveries prints a path, one line per payload and a
   --  tab between its two fields: a tab, line feed or carriage return as
   --  \t, \n or \r, any other control byte as \xHH, and -- where '\' is not
   --  the host's separator, so a name may hold one -- '\' as \\. A path
   --  then stays on its line and in its field, and no name sends the
   --  terminal an escape sequence. Every other byte (UTF-8 included) is as
   --  it is, so a path with nothing to escape prints unchanged.
   --
   --  @param Text A path.
   --  @return Its printed form.
   function Escaped (Text : String) return String;

   --  Escaped undone: what --recover and --discard-recovery read a payload
   --  path pasted from the list as, when it does not name one as it is.
   --  An escape it does not know is kept as written.
   --
   --  @param Text A printed path.
   --  @return The path.
   function Unescaped (Text : String) return String;

end Files.Recovery_CLI;
