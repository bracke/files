separate (Files.Operations)
function Toggle_Permission_Bit
  (Model    : in out Files.Model.Window_Model;
   Bit      : Natural;
   Settings : Files.Settings.Settings_Model)
   return Operation_Result
is
begin
   if Bit > 8 or else not Permissions_Editable_Selection (Model) then
      return Disabled (Model, "error.selection.empty");
   end if;

   declare
      Item     : constant Files.File_System.Directory_Item := Files.Model.Selected_Item (Model);
      Available : Boolean;
      Mode : constant Natural := Files.File_System.Permission_Bits_Of (To_String (Item.Full_Path), Available);
      Mask     : constant Natural := 2 ** (8 - Bit);
      New_Mode : constant Natural :=
        (if (Mode / Mask) mod 2 = 1
         then Mode - Mask
         else Mode + Mask);
   begin
      if not Available then
         Files.Model.Set_Error (Model, "error.permissions.failed");
         return Make_Result (Operation_Failed, "error.permissions.failed", To_String (Item.Full_Path));
      end if;
      return Set_Permissions_For (Model, New_Mode, Settings);
   end;
end Toggle_Permission_Bit;
