separate (Files.Operations)
function Resolve_Paste_Conflict
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Choice    : Conflict_Choice;
   Apply_All : Boolean)
   return Operation_Result
is
begin
   if not Files.Model.Paste_Conflict_Is_Active (Model) then
      return Disabled (Model, "error.selection.empty");
   end if;

   if Choice = Choice_Cancel then
      Files.Model.Clear_Paste_Conflict (Model);
      Files.Model.Set_Error (Model, "");
      return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
   end if;

   declare
      Decision : constant Files.Paste.Item_Decision :=
        (case Choice is
           when Choice_Replace => Files.Paste.Decision_Replace,
           when Choice_Skip    => Files.Paste.Decision_Skip,
           when Choice_Rename  => Files.Paste.Decision_Rename,
           when Choice_Cancel  => Files.Paste.Decision_Skip);
   begin
      if Apply_All then
         Files.Model.Set_Paste_Conflict_Policy
           (Model,
            (case Choice is
               when Choice_Replace => Files.Paste.Policy_Replace_All,
               when Choice_Skip    => Files.Paste.Policy_Skip_All,
               when Choice_Rename  => Files.Paste.Policy_Rename_All,
               when Choice_Cancel  => Files.Paste.Policy_Skip_All));
      else
         Files.Model.Set_Paste_Conflict_Override
           (Model, Files.Model.Paste_Conflict_Of (Model).Index, Decision);
      end if;
   end;

   declare
      --  Read after the choice above was recorded.
      Conflict : constant Files.Model.Paste_Conflict_State := Files.Model.Paste_Conflict_Of (Model);
      Work     : constant Files.Paste.Work_Item_Vectors.Vector := Conflict.Items;
      Existing : constant Files.Types.String_Vectors.Vector :=
        Conflict.Existing;
      Policy   : constant Files.Paste.Conflict_Policy := Conflict.Policy;
      Overrides : constant Files.Paste.Item_Decision_Vectors.Vector :=
        Conflict.Overrides;
      Mode     : constant Files.File_System.Drop_Import_Mode :=
        Conflict.Mode;
      Next     : constant Natural :=
        Files.Paste.Next_Unresolved_Conflict (Work, Policy, Overrides, Existing);
   begin
      if Next /= 0 then
         Files.Model.Set_Paste_Conflict_Index (Model, Next);
         return Make_Result (Operation_Success, Path => Files.Model.Current_Path (Model));
      end if;

      declare
         Actions : constant Files.Paste.Resolved_Action_Vectors.Vector :=
           Files.Paste.Resolve
             (Work, Policy, Overrides, Existing,
              Fold_Names =>
                not Work.Is_Empty and then Hostkit.Fs.Folds_Name_Case (To_String (Work.First_Element.Dest_Dir)),
              Dos_Names =>
                not Work.Is_Empty
                and then Hostkit.Fs.Uses_Dos_Filename_Rules (To_String (Work.First_Element.Dest_Dir)));
         --  Carry the clipboard-clearing intent (clipboard paste vs
         --  drag-and-drop) captured when the conflict dialog was armed, since
         --  Clear_Paste_Conflict below resets it.
         Clears_Clipboard : constant Boolean :=
           Conflict.Clears_Clipboard;
      begin
         --  Leave the conflict sub-mode, arm the resumable execution over the
         --  resolved actions, and run the first batch (small pastes finish
         --  here; larger ones continue under the render loop).
         Files.Model.Clear_Paste_Conflict (Model);
         Files.Operations.Begin_Paste_Execution (Model, Actions, Mode, Clears_Clipboard);
         return Advance_Paste_Execution (Model, Settings, Paste_Execution_First_Batch);
      end;
   end;
end Resolve_Paste_Conflict;
