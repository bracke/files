with Files.Settings.Open_Actions;
separate (Files.Operations)
function Open_Selected
  (Model     : in out Files.Model.Window_Model;
   Settings  : Files.Settings.Settings_Model;
   Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers)
   return Operation_Result
is
   Items : constant Files.Items.Item_Vectors.Vector := Files.Model.Selection.Selected_Items (Model);
begin
   if Files.Model.Selection.Selected_Count (Model) = 0
     or else Files.Model.Selection.Includes_Temporary (Model)
   then
      return Disabled (Model, "error.selection.empty");
   elsif Natural (Items.Length) > 1 then
      declare
         --  The checks every item must pass (no folder, an action for its
         --  type, no unsafe placeholder) are Prepare's, which also reports
         --  the first refusal.
         Prepared : constant Operation_Result := Prepare_Open_Selected_Action (Model, Settings, Modifiers);
         Actions  : Files.Desktop_Applications.Open_Action_Vectors.Vector;
         Paths    : Files.Types.String_Vectors.Vector;
      begin
         if Prepared.Status /= Operation_Success then
            return Prepared;
         end if;
         for Item of Items loop
            Actions.Append
              (Files.Settings.Open_Actions.Expand_Placeholders
                 (Files.Settings.Open_Actions.Lookup_Open_Action
                    (Settings, To_String (Item.Filetype), Modifiers).Action,
                  To_String (Item.Full_Path)));
            Paths.Append (Item.Full_Path);
         end loop;
         return Launch_Open_Actions (Model, Actions, Paths);
      end;
   end if;

   declare
      Prepared : constant Operation_Result := Prepare_Open_Selected_Action (Model, Settings, Modifiers);
   begin
      if Prepared.Status /= Operation_Success then
         return Prepared;
      elsif To_String (Prepared.Action.Executable) = "" then
         declare
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory_Deferring_Thumbnails (To_String (Prepared.Path), Settings);
         begin
            if not Load.Success then
               Files.Model.Set_Error (Model, To_String (Load.Error_Key));
               return Make_Result (Operation_Failed, To_String (Load.Error_Key), To_String (Prepared.Path));
            end if;

            Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);
            Settle_Current_Is_Trash (Model);
            Files.Model.Set_Directory_Signature (Model, Load.Signature);
            --  Opening a folder records it too: recent folders are useful.
            Files.Model.Note_Recent_Open (Model, To_String (Load.Path));
            Files.Model.Set_Error (Model, "");
            --  Last, once the listing it refreshes is the current one.
            Support.Generate_Missing_Thumbnails (Model, Settings, Load.Items);
            return Make_Result (Operation_Navigated, Path => To_String (Load.Path));
         end;
      end if;
      return
        Launch_Open_Actions
          (Model,
           Files.Desktop_Applications.Open_Action_Vectors.To_Vector (Prepared.Action, 1),
           Files.Types.String_Vectors.To_Vector (Prepared.Path, 1));
   end;
end Open_Selected;
