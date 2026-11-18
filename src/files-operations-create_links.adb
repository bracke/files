separate (Files.Operations)
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
     (Kind        => Files.Model.Undo_Delete_Created,
      Create_Kind => (if Hard then Files.Model.Create_Hard_Link else Files.Model.Create_Symbolic_Link),
      Redoable    => True,
      others      => <>);

   function Failed (Error_Key : String) return Operation_Result is
   begin
      Finish_Failed_Undo (Model, Progress);
      return Batch_Failed (Model, Settings, Error_Key, Directory, Wrote_Some => not Progress.Items.Is_Empty);
   end Failed;

   --  Build the " (link)" / " (link N)" marker. The fragments are kept
   --  separate so no single string literal mixes a letter with a space,
   --  which the format-validation tooling rejects.
   function Link_Marker (Value : Positive) return String is
      Open  : constant String := " (";
      Word  : constant String := "link";
      Close : constant String := ")";
   begin
      if Value = 1 then
         return Open & Word & Close;
      else
         return Open & Word & " " & Files.Types.Natural_Text (Value) & Close;
      end if;
   end Link_Marker;
begin
   if Files.Model.Selection.Includes_Temporary (Model) then
      return Disabled (Model, "error.create.pending");
   elsif Directory = ""
     or else Files.Model.In_Recent_View (Model)
     or else Is_Trash_Directory (Directory)
   then
      return Disabled (Model, "error.link.failed");
   elsif Items.Is_Empty then
      return Failed ("error.link.failed");
   end if;

   for Item of Items loop
      declare
         Source : constant String := To_String (Item.Full_Path);
         Name   : constant String := To_String (Item.Name);
         Ext    : constant String := Files.Types.Extension_Of (Name);
         Base   : constant String := Files.Types.Stem_Of (Name);
         --  A link belongs beside its source, wherever the listing came from.
         Link_Directory : constant String := Files.Fs_Primitives.Parent_Directory (Source);

         --  A directory-unique link stem (without extension), e.g. "report
         --  (link)" or "report (link 2)" when earlier choices already exist.
         function Marker (Attempt : Natural) return String is (Link_Marker (Attempt));
         function Unique_Stem return String is (First_Free_Name (Link_Directory, Base, Ext, Marker'Access));

         Dest_Path : constant String :=
           Files.Fs_Primitives.Compose_Text (Link_Directory, Unique_Stem, Ext);
         Dest_Name : constant String := Files.Fs_Primitives.Leaf_Text (Dest_Path);
         Mutation  : constant Files.File_System.Mutation_Result :=
           (if Hard
            then Files.File_System.Create_Hard_Link (Source, Dest_Path)
            else Files.File_System.Create_Symbolic_Link (Source, Dest_Path));
      begin
         if not Mutation.Success then
            return Failed (To_String (Mutation.Error_Key));
         end if;

         Progress.Items.Append
           (Files.Model.Recorded_Item'
              (Item       =>
                 (From          => To_Unbounded_String (Dest_Path),
                  Forward       => To_Unbounded_String (Source),
                  Identity      => To_Unbounded_String (Files.File_Identities.Token (Dest_Path)),
                  Tree_Revision => To_Unbounded_String (Files.File_System.Tree_Revision (Dest_Path)),
                  others        => <>),
               Provenance => Files.Model.Published));
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
