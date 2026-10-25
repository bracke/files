separate (Files.Operations)
function Begin_Paste_To
  (Model          : in out Files.Model.Window_Model;
   Settings       : Files.Settings.Settings_Model;
   Source_Paths   : Files.Types.String_Vectors.Vector;
   Destination    : String;
   Mode           : Files.File_System.Drop_Import_Mode := Files.File_System.Drop_Copy;
   From_Clipboard : Boolean := True)
   return Operation_Result
is
   Directory : constant String := Destination;
   Plans     : Files.File_System.Drop_Import_Result;
begin
   if Files.Model.Paste_Execution_Is_Active (Model) or else Files.Model.Paste_Conflict_Is_Active (Model) then
      return Make_Result (Operation_Disabled, Path => Directory);
   end if;
   if Source_Paths.Is_Empty then
      return Disabled (Model, "error.drop.invalid_source");
   end if;
   if Directory = "" or else Is_Trash_Directory (Directory) then
      return Disabled (Model, "error.drop.invalid_destination");
   end if;
   if Files.Model.Temporary_Item_Is_Active (Model) then
      return Disabled (Model, "error.create.pending");
   end if;
   if Mode = Files.File_System.Drop_Move then
      for Source of Source_Paths loop
         if Is_Trash_Child (To_String (Source)) then
            return Disabled (Model, "error.drop.invalid_source");
         end if;
      end loop;
   end if;

   --  Reuse the drag-and-drop planner purely to validate the sources
   --  (missing source, invalid name, drop-into-self) and to detect same-dir
   --  move no-ops; its auto-renamed destinations are discarded.
   Plans := Files.File_System.Plan_Drop_Import (Source_Paths, Directory, Mode);
   if not Plans.Success then
      Files.Model.Set_Error (Model, To_String (Plans.Error_Key));
      return Make_Result (Operation_Failed, To_String (Plans.Error_Key), Directory);
   end if;

   declare
      Work     : constant Files.Paste.Work_Item_Vectors.Vector :=
        Paste_Work_List (Plans.Plans, Directory);
      Existing : constant Files.Types.String_Vectors.Vector :=
        With_Case_Aliases (Work, Existing_Destination_Paths (Directory), Directory);
      Conflict : constant Natural :=
        Files.Paste.Next_Unresolved_Conflict
          (Work, Files.Paste.Policy_Ask, Files.Paste.Item_Decision_Vectors.Empty_Vector, Existing);
   begin
      if Conflict = 0 then
         --  No collisions: arm the resumable execution and run the first
         --  batch. Small pastes finish here; larger ones keep advancing under
         --  the render loop while the progress overlay is shown.
         declare
            Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
              Files.Paste.Resolve
                (Work, Files.Paste.Policy_Ask,
                 Files.Paste.Item_Decision_Vectors.Empty_Vector, Existing);
         begin
            Files.Model.Begin_Paste_Execution (Model, Actions, Mode, From_Clipboard);
            return Advance_Paste_Execution (Model, Settings, Paste_Execution_First_Batch);
         end;
      else
         --  Collisions remain: arm the conflict dialog and write nothing yet.
         Files.Model.Begin_Paste_Conflict (Model, Work, Existing, Mode, Conflict, From_Clipboard);
         Files.Model.Set_Error (Model, "");
         return Make_Result (Operation_Success, Path => Directory);
      end if;
   end;
end Begin_Paste_To;
