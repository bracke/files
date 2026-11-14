with Ada.Strings.Unbounded;

with Files.Folder_Size;
with Files.Folder_Size.Testing;
with Files.Model.Support;

package body Files.Model.Testing is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   function Folder_Scan_Is_Active (Model : Window_Model) return Boolean is
     (Files.Folder_Size.Is_Active (Model.Folder_Scan));

   function Folder_Scan_Target (Model : Window_Model) return String is
     (Files.Folder_Size.Testing.Target (Model.Folder_Scan));

   function Rename_Field_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Rename.Fields.Length);
   end Rename_Field_Count;

   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural)
   is
      Field_Index : constant Natural :=
        (if Model.Rename.Active then Find_Rename_Field (Model, Visible_Index) else 0);
   begin
      if Field_Index = 0 then
         Active := False;
         Value  := Null_Unbounded_String;
         Cursor := 0;
      else
         declare
            Field : constant Rename_Field := Model.Rename.Fields.Element (Field_Index);
         begin
            Active := True;
            Value  := Field.Edit.Text;
            Cursor := Field.Edit.Cursor;
         end;
      end if;
   end Rename_State_For_Visible;

   function Selected_Item_Is_Temporary
     (Model : Window_Model)
      return Boolean is
   begin
      return Effective_Selected_Item_Index (Model) = Temporary_Item_Index and then Temporary_Is_Visible (Model);
   end Selected_Item_Is_Temporary;

   function Selection_Grid_Columns
     (Model : Window_Model)
      return Positive is
   begin
      return Model.Selection_Columns;
   end Selection_Grid_Columns;

   function Undo_Kind_Of
     (Model : Window_Model)
      return Undo_Action_Kind is
   begin
      if Model.History.Undo_Stack.Is_Empty then
         return Undo_None;
      end if;

      return Model.History.Undo_Stack.Last_Element.Kind;
   end Undo_Kind_Of;

   function Undo_To_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      if Model.History.Undo_Stack.Is_Empty then
         return Files.Types.String_Vectors.Empty_Vector;
      end if;

      return Model.History.Undo_Stack.Last_Element.To;
   end Undo_To_Paths;

   function Item_At (Model : Window_Model; Index : Positive) return Files.Items.Directory_Item is
     (Model.Items (Index));

   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System.Directory_Size_Result) is
   begin
      Touch_Header (Model);
      Model.Folder_Sizes.Include (To_Unbounded_String (Path), Value);
   end Set_Folder_Size;

   procedure Clear_Tree_Pick
     (Model : in out Window_Model)
     renames Files.Model.Clear_Tree_Pick;

   function Overlay_Is_Open
     (Model   : Window_Model;
      Overlay : Input_Overlay)
      return Boolean
     renames Files.Model.Overlay_Is_Open;

   procedure Cancel_Create_File
     (Model : in out Window_Model)
     renames Files.Model.Cancel_Create_File;

end Files.Model.Testing;
