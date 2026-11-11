with Hostkit.Durability;

--  Making what was written stay written, as Hostkit.Durability does it,
--  through one door: every flush the program asks for goes through here.
--  A flush that fails is what a dying disk or a pulled stick produces, and
--  what a copy, a move or a recovery stage must survive; the test suite
--  makes one fail here (Files.Durability.Testing), the same on every host.
package Files.Durability is

   --  Put a file's contents on the device.
   --
   --  @param Path The file.
   --  @return As Hostkit.Durability.Sync_File: Synced, Failed, or
   --    Not_Supported.
   function Sync_File (Path : String) return Hostkit.Durability.Outcome;

   --  Put an open file's contents on the device through the descriptor it
   --  was written by, as Hostkit.Durability.Sync_Descriptor does.
   --
   --  @param Descriptor A C runtime file descriptor open for writing.
   --  @param Path The file the descriptor is open on.
   --  @return Synced, Failed, or Not_Supported.
   function Sync_Descriptor (Descriptor : Integer; Path : String) return Hostkit.Durability.Outcome;

   --  Put a directory's entries on the device: the names made, renamed and
   --  removed in it.
   --
   --  @param Path The directory.
   --  @return As Hostkit.Durability.Sync_Directory: Synced, Failed, or
   --    Not_Supported.
   function Sync_Directory (Path : String) return Hostkit.Durability.Outcome;

private

   --  Set only by the test suite (Files.Durability.Testing): from then on a
   --  flush fails, without being asked for, when its path ends with Suffix
   --  (not "" -- separators compared as one), or, with Stage, when it is a
   --  recovery stage's folder that already holds its payload. The program
   --  never sets it.
   --
   --  @param Suffix The path ending whose flushes fail, or "" for none.
   --  @param Stage Whether a stage holding its payload fails its flush.
   procedure Set_Faults (Suffix : String; Stage : Boolean);

end Files.Durability;
