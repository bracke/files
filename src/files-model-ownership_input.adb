with Files.Model.Support;
with Ada.Strings.Fixed;

package body Files.Model.Ownership_Input is
   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   procedure Focus_Ownership_Input
     (Model         : in out Window_Model;
      Editing_Group : Boolean)
   is
      Item : constant Files.File_System.Directory_Item := Selected_Item (Model);
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      if Selected_Count (Model) /= 1
        or else Selection_Includes_Temporary (Model)
        or else not Files.File_System.Supports_Ownership
        or else not Item.Ownership_Available
        or else Current_Path (Model) = Files.File_System.Trash_Files_Directory
      then
         return;
      end if;

      Reset_Type_Ahead (Model);
      Model.Focus_Value := Files.Types.Focus_Ownership_Input;
      Model.Ownership_Editing_Group_Value := Editing_Group;
      declare
         Id   : constant Natural := (if Editing_Group then Item.Group_Id else Item.Owner_Id);
         --  Seed with the resolved name so the field matches its display; the
         --  commit path accepts a name or a number. Fall back to the number.
         Name : constant String :=
           (if Editing_Group
            then Files.File_System.Group_Name_For_Id (Id)
            else Files.File_System.User_Name_For_Id (Id));
      begin
         Model.Ownership_Input_Value :=
           To_Unbounded_String
             (if Name /= "" then Name
              else Ada.Strings.Fixed.Trim (Natural'Image (Id), Ada.Strings.Both));
      end;
      Model.Ownership_Input_Cursor := Length (Model.Ownership_Input_Value);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
   end Focus_Ownership_Input;

   function Ownership_Input_Text
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Ownership_Input_Value);
   end Ownership_Input_Text;

   procedure Set_Ownership_Input_Text
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Ownership_Input_Value := To_Unbounded_String (Text);
      Model.Ownership_Input_Cursor := Text'Length;
   end Set_Ownership_Input_Text;

   function Ownership_Editing_Group
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Ownership_Editing_Group_Value;
   end Ownership_Editing_Group;

end Files.Model.Ownership_Input;
