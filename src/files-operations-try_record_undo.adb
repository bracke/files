separate (Files.Operations)
function Try_Record_Undo
  (Model       : in out Files.Model.Window_Model;
   Kind        : Files.Model.Undo_Action_Kind;
   From        : Files.Types.String_Vectors.Vector;
   To          : Files.Types.String_Vectors.Vector;
   Forward     : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Create_Kind : Files.Model.Undo_Create_Kind := Files.Model.Create_None;
   Redoable    : Boolean := True;
   Restore_Trash : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Original_Identities : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Original_Tree_Revisions : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Original_Restore_Identities : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Original_Restore_Targets : Files.Types.String_Vectors.Vector :=
     Files.Types.String_Vectors.Empty_Vector;
   Retain_Verified_Main : Natural := 0;
   Retain_Verified_Restores : Natural := 0) return Boolean is
   use type Files.Model.Undo_Create_Kind;
   function Identity_Matches (Path, Expected : String) return Boolean
     renames Files.File_System.Entry_Identity_Matches;
   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean) return Boolean
     renames Files.File_System.Creation_Matches;
   function Valid_Natural_Image (Value : Files.Types.UString) return Boolean
     renames Files.Model.Valid_Natural_Image;
   function Valid_Ownership_Image (Value : Files.Types.UString) return Boolean
     renames Files.Model.Valid_Ownership_Image;
   Identities, Tree_Revisions, Restore_Identities, Restore_Targets : Files.Types.String_Vectors.Vector;
   Targets : Files.Types.String_Vectors.Vector := To;
   Kept_From, Kept_To, Kept_Forward : Files.Types.String_Vectors.Vector;
   Kept_Identities, Kept_Tree_Revisions : Files.Types.String_Vectors.Vector;
   Invalid_Main : Boolean := False;
   Invalid_Restore : Boolean := False;
   Recorded : Boolean;

   function Tree_Revision_Or_Empty (Path : String) return String is
   begin
      return Files.File_System.Tree_Revision (Path);
   exception
      --  A creation may already be published when its snapshot is captured.
      --  Keep the operation successful, but omit unsafe Undo for this entry.
      when others =>
         return "";
   end Tree_Revision_Or_Empty;

   function Main_Was_Verified (Index : Positive) return Boolean is
     (Index <= Retain_Verified_Main
      and then Index <= Original_Identities.Last_Index
      and then
        (Kind /= Files.Model.Undo_Delete_Created
         or else Index <= Original_Tree_Revisions.Last_Index));

   function Restore_Was_Verified (Index : Positive) return Boolean is
     (Index <= Retain_Verified_Restores
      and then Index <= Original_Restore_Identities.Last_Index
      and then Index <= Original_Restore_Targets.Last_Index);

   function Payload_Is_Complete (Index : Positive) return Boolean is
   begin
      case Kind is
         when Files.Model.Undo_Delete_Created =>
            return not Redoable
              or else (Create_Kind /= Files.Model.Create_None
                and then Index <= Forward.Last_Index
                and then Length (Forward (Index)) > 0);
         when Files.Model.Undo_Rename | Files.Model.Undo_Move | Files.Model.Undo_Restore_Trash =>
            return Index <= Targets.Last_Index
              and then Length (Targets (Index)) > 0
              and then (Kind /= Files.Model.Undo_Restore_Trash or else not Redoable);
         when Files.Model.Undo_Set_Permissions =>
            return Index <= Targets.Last_Index
              and then Valid_Natural_Image (Targets (Index))
              and then (not Redoable
                or else (Index <= Forward.Last_Index
                  and then Valid_Natural_Image (Forward (Index))));
         when Files.Model.Undo_Set_Ownership =>
            return Index <= Targets.Last_Index
              and then Valid_Ownership_Image (Targets (Index))
              and then (not Redoable
                or else (Index <= Forward.Last_Index
                  and then Valid_Ownership_Image (Forward (Index))));
         when Files.Model.Undo_None =>
            return False;
      end case;
   end Payload_Is_Complete;
begin
   --  The model advances its revision and notes completed renames and moves;
   --  everything that reads the filesystem happens here, before the model
   --  commits the entry.
   Files.Model.Begin_Undo_Record (Model, Kind, From, To);
   if Kind = Files.Model.Undo_None or else From.Is_Empty then
      return False;
   end if;
   if Kind in Files.Model.Undo_Delete_Created | Files.Model.Undo_Rename | Files.Model.Undo_Move
     | Files.Model.Undo_Restore_Trash | Files.Model.Undo_Set_Permissions | Files.Model.Undo_Set_Ownership
   then
      for Index in From.First_Index .. From.Last_Index loop
         Identities.Append
           ((if Index <= Original_Identities.Last_Index then Original_Identities (Index)
             else To_Unbounded_String (Files.File_Identities.Token (To_String (From (Index))))));
         Tree_Revisions.Append
           ((if Index <= Original_Tree_Revisions.Last_Index then Original_Tree_Revisions (Index)
             elsif Kind = Files.Model.Undo_Delete_Created then
                To_Unbounded_String (Tree_Revision_Or_Empty (To_String (From (Index))))
             else Null_Unbounded_String));
      end loop;
   end if;

   if Kind = Files.Model.Undo_Restore_Trash then
      for Index in From.First_Index .. From.Last_Index loop
         if Index > Targets.Last_Index then
            Targets.Append (To_Unbounded_String (Files.File_System.Trash_Original_Path (To_String (From (Index)))));
         end if;
      end loop;
   end if;

   for Index in Restore_Trash.First_Index .. Restore_Trash.Last_Index loop
      Restore_Targets.Append
        ((if Index <= Original_Restore_Targets.Last_Index then Original_Restore_Targets (Index)
          else To_Unbounded_String (Files.File_System.Trash_Original_Path (To_String (Restore_Trash (Index))))));
      Restore_Identities.Append
        ((if Index <= Original_Restore_Identities.Last_Index then Original_Restore_Identities (Index)
          else To_Unbounded_String (Files.File_Identities.Token (To_String (Restore_Trash (Index))))));
   end loop;
   if not Restore_Trash.Is_Empty and then Redoable then
      Invalid_Restore := True;
   end if;

   for Index in Restore_Trash.First_Index .. Restore_Trash.Last_Index loop
      if Index > Restore_Identities.Last_Index
        or else Index > Restore_Targets.Last_Index
        or else Length (Restore_Targets (Index)) = 0
        or else (not Restore_Was_Verified (Index)
          and then not Identity_Matches
            (To_String (Restore_Trash (Index)), To_String (Restore_Identities (Index))))
        or else Length (Restore_Identities (Index)) = 0
      then
         Invalid_Restore := True;
      end if;
   end loop;

   for Index in From.First_Index .. From.Last_Index loop
      declare
         Valid : constant Boolean :=
           Index <= Identities.Last_Index
           and then Index <= Tree_Revisions.Last_Index
           and then Payload_Is_Complete (Index)
           and then
             (if Kind = Files.Model.Undo_Delete_Created
              then Creation_Snapshot_Matches
                (To_String (From (Index)), To_String (Identities (Index)),
                 To_String (Tree_Revisions (Index)), Main_Was_Verified (Index))
              else (Length (Identities (Index)) > 0
                and then (Main_Was_Verified (Index)
                  or else Identity_Matches
                    (To_String (From (Index)), To_String (Identities (Index))))));
      begin
         if Valid then
            Kept_From.Append (From (Index));
            if Kind /= Files.Model.Undo_Delete_Created then
               Kept_To.Append (Targets (Index));
            end if;
            if Redoable
              and then Kind in Files.Model.Undo_Delete_Created | Files.Model.Undo_Set_Permissions
                | Files.Model.Undo_Set_Ownership
            then
               Kept_Forward.Append (Forward (Index));
            end if;
            Kept_Identities.Append (Identities (Index));
            Kept_Tree_Revisions.Append (Tree_Revisions (Index));
         else
            Invalid_Main := True;
         end if;
      end;
   end loop;

   --  A replacement reversal must remove or move every created destination
   --  before restoring its preserved originals. Dropping only an
   --  unverifiable member would make those steps refer to different sets.
   if Invalid_Restore or else (not Restore_Trash.Is_Empty and then Invalid_Main) then
      Kept_From.Clear;
   end if;

   --  The model retires the redo stack (and, past its depth cap, the oldest
   --  undo entries) before pushing; their payloads are deleted and the
   --  journal saved only once the entries have left both stacks.
   Recorded := Files.Model.Commit_Undo_Record
     (Model,
      Files.Model.Undo_Entry'
        (Kind          => Kind,
         From          => Kept_From,
         To            => Kept_To,
         Forward       => Kept_Forward,
         Create_Kind   => Create_Kind,
         Redoable      => Redoable,
         Restore_Trash => Restore_Trash,
         Restore_Identities => Restore_Identities,
         Restore_Targets => Restore_Targets,
         Created_Identities => Kept_Identities,
         Created_Tree_Revisions => Kept_Tree_Revisions,
         others        => <>));
   Settle_History (Model);
   return Recorded;
end Try_Record_Undo;
