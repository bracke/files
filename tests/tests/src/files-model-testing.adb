with Ada.Strings.Unbounded;

with Files.Folder_Size;
with Files.Folder_Size.Measuring;
with Files.Folder_Size.Measuring.Testing;
with Files.Model.History;
with Files.Model.Support;

package body Files.Model.Testing is

   use Files.Model.Support;
   use Ada.Strings.Unbounded;

   function Folder_Scan_Is_Active (Model : Window_Model) return Boolean is
     (Files.Folder_Size.Measuring.Testing.Is_Active (Model.Folder_Scan));

   function Folder_Scan_Target (Model : Window_Model) return String is
     (Files.Folder_Size.Measuring.Testing.Target (Model.Folder_Scan));

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
      --  The item the row shows: Temporary_Item_Index for the pending
      --  create row, zero for no row.
      Is_Temporary : constant Boolean :=
        Temporary_Is_Visible (Model) and then Visible_Index = Visible_Count (Model);
      Loaded       : constant Natural :=
        (if Is_Temporary then Temporary_Item_Index else Visible_To_Item_Index (Model, Visible_Index));
      Shown        : constant Boolean := Loaded /= 0;
      Field_Index : Natural := 0;
   begin
      if Model.Rename.Active and then Shown then
         for Index in Model.Rename.Fields.First_Index .. Model.Rename.Fields.Last_Index loop
            if Model.Rename.Fields.Element (Index).Item_Index = Loaded then
               Field_Index := Index;
               exit;
            end if;
         end loop;
      end if;
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
      --  The primary selection, else the first of a multi-selection.
      Effective : constant Natural :=
        (if Model.Selected_Item_Index /= 0 then Model.Selected_Item_Index
         elsif not Model.Selected_Item_Indexes.Is_Empty
         then Model.Selected_Item_Indexes.Element (Model.Selected_Item_Indexes.First_Index)
         else 0);
   begin
      return Effective = Temporary_Item_Index and then Temporary_Is_Visible (Model);
   end Selected_Item_Is_Temporary;

   function Selection_Grid_Columns
     (Model : Window_Model)
      return Positive is
   begin
      return Model.Selection_Columns;
   end Selection_Grid_Columns;

   function Undo_Kind_Of
     (Model : Window_Model)
      return Files.Undo.History.Undo_Action_Kind is
   begin
      if Model.History.Undo_Stack.Is_Empty then
         return Files.Undo.History.Undo_None;
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

      return Paths : Files.Types.String_Vectors.Vector do
         for Item of Model.History.Undo_Stack.Last_Element.Items loop
            Paths.Append (Item.To);
         end loop;
      end return;
   end Undo_To_Paths;

   function Item_At (Model : Window_Model; Index : Positive) return Files.Items.Directory_Item is
     (Model.Items (Index));

   procedure Set_Folder_Size
     (Model : in out Window_Model;
      Path  : String;
      Value : Files.File_System_Types.Directory_Size_Result) is
   begin
      --  A change to the sizes, as a hand-over is: a total kept from the
      --  ones before no longer holds.
      Note_Folder_Sizes (Model);
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

   function Paste_Execution_Done (Model : Window_Model) return Natural is (Model.Paste_Exec.Done);

   function Paste_Execution_Total (Model : Window_Model) return Natural is (Model.Paste_Exec.Total);

   function Restore_Journal (Directory : String; Model : in out Window_Model) return Boolean is
      use type Files.Undo.Journal.Read_Outcome;
      Journal : Files.Undo.Journal.Journal_Contents;
   begin
      if Files.Undo.Journal.Read (Directory, Journal) /= Files.Undo.Journal.Read_Whole then
         return False;
      end if;
      Files.Model.History.Restore (Model, Journal.Undo, Journal.Redo, Journal.State);
      return True;
   end Restore_Journal;

   function Merge_Journal
     (Directory : String;
      Model     : in out Window_Model) return Files.Undo.Journal.Read_Outcome
   is
      use type Files.Undo.Journal.Read_Outcome;
      Journal : Files.Undo.Journal.Journal_Contents;
      Outcome : constant Files.Undo.Journal.Read_Outcome := Files.Undo.Journal.Read (Directory, Journal);
   begin
      if Outcome = Files.Undo.Journal.Read_Whole then
         Files.Model.History.Merge (Model, Journal.Undo, Journal.Redo, Journal.State);
      end if;
      return Outcome;
   end Merge_Journal;

   procedure Save_Journal_To
     (Directory : String;
      Model     : Window_Model;
      Mode      : Files.Undo.Journal.Save_Mode := Files.Undo.Journal.Best_Effort) is
   begin
      Files.Undo.Journal.Save_To (Directory, Files.Model.History.State (Model), Mode);
   end Save_Journal_To;

   function Journals_Newest (Model : Window_Model; Side : Files.Undo.History.History_Side) return Boolean is
     (Files.Undo.Journal.Journals_Newest (Files.Model.History.State (Model), Side));

   function Journal_State (Model : Window_Model) return Files.Undo.History.History_Journal_State is
     (Model.History.Journal);

end Files.Model.Testing;
