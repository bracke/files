--  The system trash: moving entries there, what is in it, and putting
--  them back. Clients with this, not the whole of Files.File_System.
package Files.File_System.Trash is

   --  Return whether a platform trash backend is available in the current environment.
   --
   --  @return True when Move_To_Trash can use a configured trash location.
   function Trash_Is_Available return Boolean;

   --  Validate whether an entry can be moved to the selected trash backend.
   --
   --  This performs non-mutating checks used before multi-item delete so later
   --  failures do not move earlier selected files.
   --
   --  @param Path Entry to preflight for trash movement.
   --  @return Success when Move_To_Trash can be attempted safely.
   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result;

   --  Return the directory that holds trashed payloads for the current backend.
   --
   --  This is <Trash_Base_Path>/files for the freedesktop XDG and home-data
   --  backends, and <Trash_Base_Path> itself for the macOS flat home backend.
   --
   --  @return Trashed-payload directory, or an empty string when unavailable.
   function Trash_Files_Directory return String;

   --  Return whether Path identifies the active trash payload directory.
   --  Filesystem identity is used when possible so aliases such as symbolic
   --  links cannot bypass trash-view safety rules.
   --
   --  @param Path Existing directory path to compare with the trash payload.
   --  @return True only when Path identifies the active payload directory.
   function Is_Trash_Files_Directory (Path : String) return Boolean;

   --  Whether Path is an item in a volume's own trash, which the trash view
   --  lists beside the home trash's items.
   --
   --  @param Path Entry to test.
   --  @return True when Path is directly in a valid volume trash's files/.
   function Is_Volume_Trash_Item (Path : String) return Boolean;

   --  Capture a payload's original path before recording restore history.
   --  @param Trashed_Path Trash or replacement recovery payload pathname.
   --  @return Original path from its sidecar, or empty on failure.
   function Trash_Original_Path (Trashed_Path : String) return String;

   --  Restore a trashed payload to its recorded original location.
   --
   --  For freedesktop backends the original path is read from the matching
   --  <base>/info/<name>.trashinfo sidecar, URL-decoded, and the payload is
   --  moved back; the sidecar is removed on success. Backends without a sidecar
   --  fail with error.trash.restore_unavailable.
   --
   --  @param Trashed_Path Payload path inside the trash files directory.
   --  @param Expected_Identity Optional history snapshot verified before restoring the payload.
   --  @param Expected_Original Authoritative restore destination captured in history.
   --  @return Mutation result with a localized error key on failure.
   function Restore_From_Trash
     (Trashed_Path : String; Expected_Identity : String := ""; Expected_Original : String := "")
      return Mutation_Result;

   --  Move an entry to trash when a supported trash backend is available.
   --
   --  @param Path Entry to move to trash.
   --  @return Mutation result with a localized error key on failure.
   function Move_To_Trash
     (Path : String)
      return Mutation_Result;

   --  As Move_To_Trash, but also report the payload's path inside the trash so
   --  callers can later restore it (used by Undo).
   --
   --  @param Path Entry to move to trash.
   --  @param Trashed_Path Set to the payload's location in the trash on success.
   --  @param Recorded_Path Where the trash says the item came from, so a
   --    restore puts it back there; empty means Path. A recovery payload
   --    names its original location this way, not its hidden stage.
   --  @return Mutation result with a localized error key on failure.
   function Move_To_Trash
     (Path          : String;
      Trashed_Path  : out Files.Types.UString;
      Recorded_Path : String := "")
      return Mutation_Result;

   --  Permanently delete a single trashed or application recovery payload and
   --  its metadata.
   --
   --  Removes the payload through Delete_Permanently and, for freedesktop
   --  backends, best-effort removes the matching <base>/info/<name>.trashinfo
   --  sidecar so the trash entry leaves no orphaned metadata behind. Sidecar
   --  removal never fails the operation; the payload deletion result is
   --  returned.
   --
   --  @param Trashed_Path Payload path inside the trash files directory.
   --  @return Mutation result with a localized error key on failure.
   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result;

end Files.File_System.Trash;
