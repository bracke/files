with Files.Items;
with Files.Model.Recent;
with Files.Name_Parts;
with Files.Text_Case;

separate (Files.Operations.Archives)
function Compress_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model;
   Format   : Archive_Format)
   return Operation_Result
is
   Items     : constant Files.Items.Item_Vectors.Vector :=
     Files.Model.Selection.Selected_Items (Model);
   Directory : constant String :=
     (if Files.Model.Recent.In_Recent_View (Model) and then not Items.Is_Empty
      then Files.IO.Fs_Primitives.Parent_Directory (To_String (Items.First_Element.Full_Path))
      else Files.Model.Current_Path (Model));

   Input_Paths : Files.Types.String_Vectors.Vector;
   Entry_Names : Files.Types.String_Vectors.Vector;
   Names_Seen  : Archive_Name_Sets.Set;
   Collection_Failed : Boolean := False;
   Links_Skipped     : Natural := 0;
   --  Devices, pipes and sockets left out (files and folders only go in).
   Others_Skipped    : Natural := 0;
   Max_Archive_Entries : constant Natural :=
     (if Format = Zip_Archive then 65_535 else 100_000);
   Max_Archive_Depth : constant Natural := 64;
   Max_Archive_Path_Bytes : constant Natural := 64 * 1024 * 1024;
   Collected_Path_Bytes : Natural := 0;

   function Record_Entry (Full, Entry_Name : String) return Boolean is
   begin
      if Names_Seen.Contains (Entry_Name)
        or else Full'Length > Max_Archive_Path_Bytes - Collected_Path_Bytes
        or else Entry_Name'Length >
          Max_Archive_Path_Bytes - Collected_Path_Bytes - Full'Length
      then
         return False;
      end if;
      Collected_Path_Bytes :=
        Collected_Path_Bytes + Full'Length + Entry_Name'Length;
      Names_Seen.Insert (Entry_Name);
      Input_Paths.Append (To_Unbounded_String (Full));
      Entry_Names.Append (To_Unbounded_String (Entry_Name));
      return True;
   end Record_Entry;

   --  Recursively collect directories and ordinary files, recording
   --  each with a directory-relative archive entry name (forward slashes).
   procedure Collect
     (Full       : String;
      Entry_Name : String;
      Depth      : Natural := 0)
   is separate;

   function Failed return Operation_Result is
   begin
      Files.Model.Set_Error (Model, "error.compress.failed");
      return Make_Result (Operation_Failed, "error.compress.failed", Directory);
   exception
      when Swallowed : others =>
         Files.Diagnostics.Note (Swallowed, "Files.Operations");
         return Make_Result (Operation_Failed, "error.compress.failed", Directory);
   end Failed;

   --  How collecting the selection ended: entries to archive, nothing usable
   --  (a walk that failed or found nothing), or a name neither writer stores.
   type Collect_Outcome is (Collected, Collection_Error, Unportable_Name);

   --  Walk each selected item into Input_Paths and Entry_Names. Items from
   --  a search or Recent can share a name ("readme.txt" from two folders):
   --  the later one is stored as "readme 2.txt" rather than the archive
   --  failing. Compared folded, so it also extracts on a volume that folds
   --  case.
   function Collect_Inputs return Collect_Outcome is separate;

   --  Write the collected entries as one archive in Format at Staged and
   --  return the writer's status. The name arrays are freed on every path.
   function Write_Staged (Staged : String) return Zlib.Status_Code is separate;

   --  Publish the archive written at Staged (with Status) as Output_Path,
   --  discard Stage, record the Undo that deletes it, and reload with it
   --  selected. A failed write, a cancel or a refused publish fails the
   --  operation and publishes nothing.
   function Publish_Archive
     (Stage, Staged, Output_Path : String; Status : Zlib.Status_Code)
      return Operation_Result
   is separate;
begin
   declare
      Refusal : constant Operation_Result := Creation_Refusal (Model, "error.compress.failed");
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;
   if Items.Is_Empty or else Directory = "" then
      return Failed;
   end if;

   case Collect_Inputs is
      when Collected =>
         null;
      when Collection_Error =>
         return Failed;
      when Unportable_Name =>
         Files.Model.Set_Error (Model, "error.compress.unportable_name");
         return Make_Result (Operation_Failed, "error.compress.unportable_name", Directory);
   end case;

   declare
      Extension : constant String :=
        (case Format is
            when Zip_Archive       => "zip",
            when Seven_Zip_Archive => "7z");
      --  ".bashrc" is all name: ".bashrc.zip", not ".zip"; so is a plain
      --  folder's: "photos.2024.zip", not "photos.zip".
      Raw_Base : constant String :=
        Files.Name_Parts.Name_Stem
          (To_String (Items.First_Element.Name), Items.First_Element.Kind = Files.Types.Directory_Item);
      Base     : constant String := (if Raw_Base = "" then "archive" else Raw_Base);

      --  A directory-unique simple archive name, e.g. "report.zip" or
      --  "report (1).zip" when the first choice already exists.
      function Unique_Name return String is
        (First_Free_Leaf (Directory, Base, Extension, Files.Leaf_Names.Numbered_Marker'Access, First => 0));

      Archive_Name : constant String := Unique_Name;
      Output_Path  : constant String := Hostkit.Fs.Join (Directory, Archive_Name);
      Stage        : constant String := Files.Jobs.Context.Create_Stage (Directory);
      Staged       : constant String := Hostkit.Fs.Join (Stage, Archive_Name);
   begin
      return Publish_Archive (Stage, Staged, Output_Path, Write_Staged (Staged));
   exception
      when others =>
         Discard_Stage (Stage);
         raise;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      return Failed;
end Compress_Selected;
