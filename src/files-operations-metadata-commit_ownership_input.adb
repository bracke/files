with Files.Items;
with Files.Model.Ownership_Input;
separate (Files.Operations.Metadata)
function Commit_Ownership_Input
  (Model    : in out Files.Model.Window_Model;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
   use type Files.Types.Account_Id;
   Raw      : constant String :=
     Ada.Strings.Fixed.Trim (Files.Model.Ownership_Input.Ownership_Input_Text (Model), Ada.Strings.Both);
   Group    : constant Boolean := Files.Model.Ownership_Input.Ownership_Editing_Group (Model);
   Item     : constant Files.Items.Directory_Item := Files.Model.Selection.Selected_Item (Model);
   Resolved : Files.Types.Account_Id := 0;
   Found    : Boolean := False;

   --  All digits: an id, taken as typed (up to 4294967295), not a name.
   function Is_Numeric (Text : String) return Boolean is
     (Text'Length > 0 and then (for all Ch of Text => Ch in '0' .. '9'));
begin
   if Is_Numeric (Raw) then
      declare
         Typed : constant Files.Types.Parsed_Account_Id := Files.Types.Parse_Account_Id (Raw);
      begin
         Found := Typed.Valid;
         Resolved := Typed.Id;
      end;
   elsif Group then
      Resolved := Files.File_System.Permissions.Group_Id_For_Name (Raw, Found);
   else
      Resolved := Files.File_System.Permissions.User_Id_For_Name (Raw, Found);
   end if;

   if not Found then
      Files.Model.Set_Error (Model, "error.ownership.invalid_name");
      Files.Model.Cancel_Focus_Or_Edit (Model);
      return Make_Result (Operation_Failed, "error.ownership.invalid_name");
   end if;

   --  Enter on the id the item already has changes nothing: no chown --
   --  which, even with the ids a file has, clears its set-user-id and
   --  set-group-id bits on Linux and macOS, and its capabilities on Linux --
   --  and no Undo for it.
   if Item.Ownership_Available
     and then Resolved = (if Group then Item.Group_Id else Item.Owner_Id)
   then
      Files.Model.Cancel_Focus_Or_Edit (Model);
      return Make_Result (Operation_Success);
   end if;

   --  Only the id edited is asked for: the other, as listed, may no longer
   --  be the file's, and is left as it is.
   return Result : constant Operation_Result :=
     (if Group
      then Set_Ownership_For (Model, Hostkit.Metadata.Keep_Id, Resolved, Settings)
      else Set_Ownership_For (Model, Resolved, Hostkit.Metadata.Keep_Id, Settings))
   do
      Files.Model.Cancel_Focus_Or_Edit (Model);
   end return;
end Commit_Ownership_Input;
