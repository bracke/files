with Files.Items;
with Files.Model.Recent;
with Files.Name_Parts;

separate (Files.Operations.Editing)
--  Shared implementation for the create-symlink and create-hard-link
--  commands. Each selected item gets a uniquely named link in the current
--  directory; the created links are recorded so Undo can delete them.
function Create_Links
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model;
   Hard     : Boolean)
   return Operation_Result
is
   Items     : constant Files.Items.Item_Vectors.Vector :=
     Files.Model.Selection.Selected_Items (Model);
   Directory : constant String := Files.Model.Current_Path (Model);

   First_Created : Unbounded_String;
   Created_Any   : Boolean := False;
   --  The batch's Undo entry, grown as it goes like every batch's: each link
   --  made, where it is, its source (what Redo links again), and its
   --  identity and revision as made. Undo deletes them, Redo links again.
   Progress      : Progressive_Undo :=
     (Kind        => Files.Undo.History.Undo_Delete_Created,
      Create_Kind => (if Hard then Files.Undo.History.Create_Hard_Link else Files.Undo.History.Create_Symbolic_Link),
      Redoable    => True,
      others      => <>);

   function Failed (Error_Key : String) return Operation_Result is
   begin
      Finish_Failed_Undo (Model, Progress);
      return Batch_Failed (Model, Settings, Error_Key, Directory, Wrote_Some => not Progress.Items.Is_Empty);
   end Failed;

   --  The " (link)" / " (link N)" marker: a fixed, unlocalized file name.
   function Link_Marker (Attempt : Natural) return String is (Files.Leaf_Names.Counted_Marker ("link", Attempt));
begin
   if Files.Model.Selection.Includes_Temporary (Model) then
      return Disabled (Model, "error.create.pending");
   elsif Directory = ""
     or else Files.Model.Recent.In_Recent_View (Model)
     or else Files.File_System.Trash.Is_Trash_Files_Directory (Directory)
   then
      return Disabled (Model, "error.link.failed");
   elsif Items.Is_Empty then
      return Failed ("error.link.failed");
   end if;

   for Item of Items loop
      declare
         Source : constant String := To_String (Item.Full_Path);
         Name   : constant String := To_String (Item.Name);
         --  A plain folder's dots are part of its name: "v1.2 (link)".
         Is_Folder : constant Boolean := Item.Kind = Files.Types.Directory_Item;
         --  A link belongs beside its source, wherever the listing came from.
         Link_Directory : constant String := Files.IO.Fs_Primitives.Parent_Directory (Source);

         --  A directory-unique link name, e.g. "report (link).txt" or
         --  "report (link 2).txt" when earlier choices already exist.
         Dest_Path : constant String :=
           Hostkit.Fs.Join
             (Link_Directory,
              First_Free_Leaf
                (Link_Directory, Files.Name_Parts.Name_Stem (Name, Is_Folder),
                 Files.Name_Parts.Name_Extension (Name, Is_Folder), Link_Marker'Access));
         Dest_Name : constant String := Files.Name_Parts.Leaf_Of (Dest_Path);
         Mutation  : constant Files.File_System.Mutation_Result :=
           (if Hard
            then Files.File_System.Create_Hard_Link (Source, Dest_Path)
            else Files.File_System.Create_Symbolic_Link (Source, Dest_Path));
      begin
         if not Mutation.Success then
            return Failed (To_String (Mutation.Error_Key));
         end if;

         Progress.Items.Append
           (Files.Undo.History.Recorded_Item'
              (Item       =>
                 (From          => To_Unbounded_String (Dest_Path),
                  Forward       => To_Unbounded_String (Source),
                  Identity      => To_Unbounded_String (Files.File_Identities.Token (Dest_Path)),
                  Tree_Revision => To_Unbounded_String (Files.File_System.Tree_Revision (Dest_Path)),
                  others        => <>),
               Provenance => Files.Undo.History.Published));
         Checkpoint_Undo (Model, Progress);
         if not Created_Any then
            First_Created := To_Unbounded_String (Dest_Name);
            Created_Any := True;
         end if;
      end;
   end loop;

   declare
      Undo : constant Undo_Outcome := Finish_Undo (Model, Progress);
   begin
      if not Created_Any then
         return Failed ("error.link.failed");
      end if;
      --  Reload so the new links appear, and select the first one; an Undo
      --  that could not be recorded is said, not left silently missing.
      declare
         Result : constant Operation_Result := Reload_Current_Directory (Model, Settings, To_String (First_Created));
      begin
         Note_Undo_Outcome (Model, Undo, Result);
         return Result;
      end;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.Operations");
      return Failed ("error.link.failed");
end Create_Links;
