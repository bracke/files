with Files.Model.Recent;
with Files.File_System.Transfer;
with Files.Name_Parts;

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
     (Kind => Files.Undo.History.Undo_Delete_Created, Create_Kind => Files.Undo.History.Create_Copy, Redoable => True,
      others => <>);

   --  The " (copy)" / " (copy N)" marker: a fixed, unlocalized file name.
   function Copy_Marker (Attempt : Natural) return String is (Files.Leaf_Names.Counted_Marker ("copy", Attempt));

   --  Copy_Tree commits one selection at a time. If a later source
   --  fails, the earlier copies stay undoable; reload so they are not
   --  hidden by a stale model, and retain the failure after that reload
   --  clears errors.
   function Failed return Operation_Result is
   begin
      Finish_Failed_Undo (Model, Progress);
      return Batch_Failed
        (Model, Settings, "error.duplicate.failed", Directory, Wrote_Some => not Progress.Items.Is_Empty);
   end Failed;
begin
   declare
      Refusal : constant Operation_Result := Creation_Refusal (Model, "error.duplicate.failed");
   begin
      if Refusal.Status /= Operation_Success then
         return Refusal;
      end if;
   end;
   if Items.Is_Empty or else (Directory = "" and then not Files.Model.Recent.In_Recent_View (Model)) then
      return Failed;
   end if;

   --  Created only now: the background path above hands the work to a
   --  helper, and the handler below must cover a failed reservation.
   declare
      Copy_Batch : constant Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Create;
   begin
      for Item of Items loop
         exit when Files.Jobs.Context.Cancelled;
         declare
            Source : constant String := To_String (Item.Full_Path);
            --  Recent and search results can select paths from several
            --  folders; each duplicate belongs beside its source.
            Destination_Directory : constant String := Files.IO.Fs_Primitives.Parent_Directory (Source);
            Name   : constant String := To_String (Item.Name);
            --  A plain folder's dots are part of its name: "v1.2 (copy)".
            Is_Folder : constant Boolean := Item.Kind = Files.Types.Directory_Item;

            --  A directory-unique copy name, e.g. "report (copy).txt" or
            --  "report (copy 2).txt" when earlier choices already exist.
            Dest_Path : constant String :=
              Hostkit.Fs.Join
                (Destination_Directory,
                 First_Free_Leaf
                   (Destination_Directory, Files.Name_Parts.Name_Stem (Name, Is_Folder),
                    Files.Name_Parts.Name_Extension (Name, Is_Folder), Copy_Marker'Access));
            Dest_Name : constant String := Files.Name_Parts.Leaf_Of (Dest_Path);
            Identity, Revision : Files.Types.UString;
            Mutation  : constant Files.File_System.Mutation_Result :=
              Files.File_System.Transfer.Copy_Tree (Source, Dest_Path, Identity, Revision, Copy_Batch);
         begin
            if not Mutation.Success then
               return Failed;
            end if;

            Progress.Items.Append
              (Files.Undo.History.Recorded_Item'
                 (Item       =>
                    (From          => To_Unbounded_String (Dest_Path),
                     Forward       => To_Unbounded_String (Source),
                     Identity      => Identity,
                     Tree_Revision => Revision,
                     others        => <>),
                  Provenance => Files.Undo.History.Published));
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
