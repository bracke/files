with Files.Model.Support;

package body Files.Model.Temporary is
   use Files.Model.Support;
   use type Files.Types.Focus_Target;
   use Ada.Strings.Unbounded;

   procedure Begin_Create_File
      (Model : in out Window_Model;
       Name  : String) is
   begin
      Begin_Create_Temporary (Model, Name, Is_Directory => False);
   end Begin_Create_File;

   procedure Begin_Create_Folder
      (Model : in out Window_Model;
       Name  : String) is
   begin
      Begin_Create_Temporary (Model, Name, Is_Directory => True);
   end Begin_Create_Folder;

   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Temporary_Active;
   end Temporary_Item_Is_Active;

   function Temporary_Item_Is_Directory
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Temporary_Is_Directory;
   end Temporary_Item_Is_Directory;

   function Temporary_Item_Name
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Temporary_Name_Value);
   end Temporary_Item_Name;

   procedure Cancel_Create_File
     (Model : in out Window_Model) is
   begin
      Model.Temporary_Active := False;
      Model.Temporary_Is_Directory := False;
      Model.Temporary_Name_Value := Null_Unbounded_String;
      if Model.Selected_Item_Index = Temporary_Item_Index then
         Model.Selected_Item_Index := 0;
      end if;
      Remove_Selected_Index (Model, Temporary_Item_Index);
      --  The temporary item owns the only rename field while it is active, so
      --  clearing rename state here discards exactly that field.
      Reset_Rename_State (Model);
      if Model.Focus_Value = Files.Types.Focus_Rename_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Cancel_Create_File;

end Files.Model.Temporary;
