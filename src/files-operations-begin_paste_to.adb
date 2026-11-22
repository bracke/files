with Files.File_System_Types;
with Files.Model.Creation;
with Files.File_System.Transfer;
with Files.IO.Fs_Primitives;
separate (Files.Operations)
function Begin_Paste_To
  (Model          : in out Files.Model.Window_Model;
   Settings       : Files.Settings.Settings_Model;
   Source_Paths   : Files.Types.String_Vectors.Vector;
   Destination    : String;
   Mode           : Files.File_System_Types.Drop_Import_Mode := Files.File_System_Types.Drop_Copy;
   From_Clipboard : Boolean := True)
   return Operation_Result
is
   Directory : constant String := Destination;
   Plans     : Files.File_System.Drop_Import_Result;

   --  The incoming destination paths that already exist, probed one by one:
   --  the fallback when the destination cannot be listed whole, so a
   --  collision is still detected rather than hidden. A dangling link counts.
   function Probed_Destinations
     (Work : Files.Paste.Work_Item_Vectors.Vector)
      return Files.Types.String_Vectors.Vector
   is
      Result : Files.Types.String_Vectors.Vector;
   begin
      for Item of Work loop
         declare
            Desired : constant String :=
              Files.Paste.Desired_Path (To_String (Item.Dest_Dir), To_String (Item.Dest_Name));
         begin
            --  A name the host will not answer for may be taken: ask.
            if not Files.IO.Fs_Primitives.Entry_Is_Absent (Desired) then
               Result.Append (To_Unbounded_String (Desired));
            end if;
         exception
            when Swallowed : others =>
               Files.Diagnostics.Note (Swallowed, "Files.Operations");
               --  Unknowable: treat it as taken, so the user is asked.
               Result.Append (To_Unbounded_String (Desired));
         end;
      end loop;
      return Result;
   end Probed_Destinations;
begin
   if Files.Model.Foreground_Job_Is_Active (Model) or else Files.Model.Pasting.Conflict_Is_Active (Model) then
      return Make_Result (Operation_Disabled, Path => Directory);
   end if;
   if Source_Paths.Is_Empty then
      return Disabled (Model, "error.drop.invalid_source");
   end if;
   if Directory = "" or else Is_Trash_Directory (Directory) then
      return Disabled (Model, "error.drop.invalid_destination");
   end if;
   if Files.Model.Creation.Temporary_Item_Is_Active (Model) then
      return Disabled (Model, "error.create.pending");
   end if;
   if Mode = Files.File_System_Types.Drop_Move then
      for Source of Source_Paths loop
         if Is_Trash_Child (To_String (Source)) then
            return Disabled (Model, "error.drop.invalid_source");
         end if;
      end loop;
   end if;

   --  Reuse the drag-and-drop planner purely to validate the sources
   --  (missing source, invalid name, drop-into-self) and to detect same-dir
   --  move no-ops; its auto-renamed destinations are discarded.
   Plans := Files.File_System.Transfer.Plan_Drop_Import (Source_Paths, Directory, Mode);
   if not Plans.Success then
      Files.Model.Set_Error (Model, To_String (Plans.Error_Key));
      return Make_Result (Operation_Failed, To_String (Plans.Error_Key), Directory);
   end if;

   declare
      Work     : constant Files.Paste.Work_Item_Vectors.Vector :=
        Paste_Work_List (Plans.Plans, Directory);
      Listed   : Boolean;
      Listing  : constant Files.Types.String_Vectors.Vector := Existing_Destination_Paths (Directory, Listed);
      Existing : constant Files.Types.String_Vectors.Vector :=
        (if Listed then Listing else Probed_Destinations (Work));
      --  Where the directory folds case, Report.txt conflicts with an
      --  existing report.txt (Files.Paste folds both lookups by these rules).
      Rules    : constant Files.Paste.Name_Rules := Files.Paste.Name_Rules_Of (Directory);
      Conflict : constant Natural :=
        Files.Paste.Next_Unresolved_Conflict
          (Work, Files.Paste.Policy_Ask, Files.Paste.Item_Decision_Vectors.Empty_Vector, Existing, Rules);
   begin
      if Conflict = 0 then
         --  No collisions: arm the resumable execution and run the first
         --  batch. Small pastes finish here; larger ones keep advancing under
         --  the render loop while the progress overlay is shown.
         declare
            Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
              Files.Paste.Resolve
                (Work, Files.Paste.Policy_Ask,
                 Files.Paste.Item_Decision_Vectors.Empty_Vector, Existing, Rules);
         begin
            Files.Operations.Begin_Paste_Execution (Model, Actions, Mode, From_Clipboard);
            return Advance_Paste_Execution (Model, Settings, Paste_Execution_First_Batch);
         end;
      else
         --  Collisions remain: arm the conflict dialog and write nothing yet.
         Files.Model.Pasting.Begin_Conflict (Model, Work, Existing, Mode, Conflict, From_Clipboard);
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Directory);
      end if;
   end;
end Begin_Paste_To;
