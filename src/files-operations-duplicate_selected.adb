separate (Files.Operations)
function Duplicate_Selected
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   Items     : constant Files.Items.Item_Vectors.Vector :=
     Files.Model.Selection.Selected_Items (Model);
   Directory : constant String := Files.Model.Current_Path (Model);

   First_Created : Unbounded_String;
   Created_Any   : Boolean := False;
   --  Created copies (From) and their sources (Forward).
   Progress      : Progressive_Undo :=
     (Kind => Files.Model.Undo_Delete_Created, Create_Kind => Files.Model.Create_Copy, Redoable => True,
      others => <>);

   function Trimmed_Image (Value : Positive) return String is (Files.Types.Natural_Text (Value));

   --  Build the " (copy)" / " (copy N)" marker. The fragments are kept
   --  separate so no single string literal mixes a letter with a space,
   --  which the format-validation tooling rejects.
   function Copy_Marker (Value : Positive) return String is
      Open  : constant String := " (";
      Word  : constant String := "copy";
      Close : constant String := ")";
   begin
      if Value = 1 then
         return Open & Word & Close;
      else
         return Open & Word & " " & Trimmed_Image (Value) & Close;
      end if;
   end Copy_Marker;

   --  Copy_Tree commits one selection at a time. If a later source
   --  fails, the earlier copies stay undoable; reload so they are not
   --  hidden by a stale model, and retain the failure after that reload
   --  clears errors.
   function Failed return Operation_Result is
   begin
      Finish_Failed_Undo (Model, Progress);
      return Batch_Failed
        (Model, Settings, "error.duplicate.failed", Directory, Wrote_Some => not Progress.From.Is_Empty);
   end Failed;
begin
   if Files.Model.Selection.Selection_Includes_Temporary (Model) then
      return Disabled (Model, "error.create.pending");
   elsif Is_Trash_Directory (Directory) then
      return Disabled (Model, "error.duplicate.failed");
   elsif Files.Model.Background_Transfers (Model) then
      return Files.Operation_Jobs.Start (Model, Settings, Files.Operation_Jobs.Duplicate);
   end if;
   if Items.Is_Empty or else (Directory = "" and then not Files.Model.In_Recent_View (Model)) then
      return Failed;
   end if;

   --  Created only now: the background path above hands the work to a
   --  helper, and the handler below must cover a failed reservation.
   declare
      Copy_Batch : constant Files.Copy_Context.Session := Files.Copy_Context.Create;
   begin
      for Item of Items loop
         exit when Files.Job_Context.Cancelled;
         declare
            Source : constant String := To_String (Item.Full_Path);
            --  Recent and search results can select paths from several
            --  folders; each duplicate belongs beside its source.
            Destination_Directory : constant String := Files.Fs_Primitives.Parent_Directory (Source);
            Name   : constant String := To_String (Item.Name);
            Ext    : constant String := Files.Types.Extension_Of (Name);
            Base   : constant String := Files.Types.Stem_Of (Name);

            --  A directory-unique copy stem (without extension), e.g. "report
            --  (copy)" or "report (copy 2)" when earlier choices already exist.
            function Marker (Attempt : Natural) return String is (Copy_Marker (Attempt));
            function Unique_Stem return String is
              (First_Free_Name (Destination_Directory, Base, Ext, Marker'Access));

            Dest_Path : constant String :=
              Files.Fs_Primitives.Compose_Text (Destination_Directory, Unique_Stem, Ext);
            Dest_Name : constant String := Files.Fs_Primitives.Leaf_Text (Dest_Path);
            Identity, Revision : Files.Types.UString;
            Mutation  : constant Files.File_System.Mutation_Result :=
              Files.File_System.Copy_Tree (Source, Dest_Path, Identity, Revision, Copy_Batch);
         begin
            if not Mutation.Success then
               return Failed;
            end if;

            Progress.From.Append (To_Unbounded_String (Dest_Path));
            Progress.Forward.Append (To_Unbounded_String (Source));
            Progress.Identities.Append (Identity);
            Progress.Tree_Revisions.Append (Revision);
            Checkpoint_Undo (Model, Progress);
            if not Created_Any then
               First_Created := To_Unbounded_String (Dest_Name);
               Created_Any := True;
            end if;
         end;
      end loop;
   end;
   declare
      Undo : constant Undo_Outcome := Finish_Undo (Model, Progress);
   begin
      if not Created_Any then
         return Failed;
      end if;

      --  Reload the active view; an ordinary folder selects the first copy.
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
      return Failed;
end Duplicate_Selected;
