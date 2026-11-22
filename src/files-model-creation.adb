with Files.Model.Support;

package body Files.Model.Creation is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   --  Begin an inline create-file/create-folder edit: clear other overlays, add
   --  the temporary row, and open a rename field pre-filled with Name.
   --
   --  @param Model Model to update.
   --  @param Name Initial name for the new item.
   --  @param Is_Directory True to create a folder, False for a file.
   procedure Begin_Create_Temporary
      (Model        : in out Window_Model;
       Name         : String;
       Is_Directory : Boolean;
       Classes      : Files.File_Types.Classification) is
   begin
      Touch (Model);
      Support.Touch_Listing (Model);
      Clear_Overlay_State_For_Edit (Model);
      Model.Temporary :=
        (Active => True, Is_Directory => Is_Directory, Name => To_Unbounded_String (Name), Classes => Classes);
      Model.Rename.Fields.Clear;
      Model.Rename.Fields.Append
        (Rename_Field'
           (Item_Index => Temporary_Item_Index,
            Edit       => (Text => To_Unbounded_String (Name), Cursor => Name'Length)));
      Model.Rename.Active := True;
      Model.Main_View_Scroll := 0;
      Model.Selected_Item_Index := Temporary_Item_Index;
      Model.Selected_Item_Indexes.Clear;
      Add_Selected_Index (Model, Temporary_Item_Index);
      Model.Focus_Value := Files.UI_Types.Focus_Rename_Input;
   end Begin_Create_Temporary;

   procedure Begin_Create_File
      (Model   : in out Window_Model;
       Name    : String;
       Classes : Files.File_Types.Classification) is
   begin
      Touch (Model);
      Begin_Create_Temporary (Model, Name, Is_Directory => False, Classes => Classes);
   end Begin_Create_File;

   procedure Begin_Create_Folder
      (Model   : in out Window_Model;
       Name    : String;
       Classes : Files.File_Types.Classification) is
   begin
      Touch (Model);
      Begin_Create_Temporary (Model, Name, Is_Directory => True, Classes => Classes);
   end Begin_Create_Folder;

   function Temporary_Item_Is_Active
     (Model : Window_Model)
      return Boolean is
     (Model.Temporary.Active);

   function Temporary_Item_Is_Directory
     (Model : Window_Model)
      return Boolean is
     (Model.Temporary.Is_Directory);

   function Temporary_Item_Name
     (Model : Window_Model)
      return String is
     (To_String (Model.Temporary.Name));

end Files.Model.Creation;
