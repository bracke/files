package body Files.Model.Paste_Exec is
   use Ada.Strings.Unbounded;

   procedure Begin_Paste_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
   is
      Writes : Natural := 0;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      for Action of Actions loop
         if not Action.Skip then
            Writes := Writes + 1;
         end if;
      end loop;

      Model.Paste_Exec_Active_Value := True;
      Model.Paste_Exec_Actions_Value := Actions;
      Model.Paste_Exec_Cursor_Value := 0;
      Model.Paste_Exec_Done_Value := 0;
      Model.Paste_Exec_Total_Value := Writes;
      Model.Paste_Exec_Mode_Value := Mode;
      Model.Paste_Exec_Clears_Clip_Value := Clear_Clipboard;
      Model.Paste_Exec_Cancelled_Value := False;
      Model.Paste_Exec_Current_Value := Null_Unbounded_String;
      Model.Paste_Exec_First_Dest_Value := Null_Unbounded_String;
      Model.Paste_Exec_Undo_From_Value.Clear;
      Model.Paste_Exec_Undo_To_Value.Clear;
      Model.Paste_Exec_Replaced_Trash_Value.Clear;
   end Begin_Paste_Execution;

   function Paste_Execution_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec_Active_Value;
   end Paste_Execution_Is_Active;

   function Paste_Execution_Done
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec_Done_Value;
   end Paste_Execution_Done;

   function Paste_Execution_Total
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec_Total_Value;
   end Paste_Execution_Total;

   function Paste_Execution_Current_Name
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Paste_Exec_Current_Value);
   end Paste_Execution_Current_Name;

   function Paste_Execution_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is
   begin
      return Model.Paste_Exec_Mode_Value;
   end Paste_Execution_Mode;

   function Paste_Execution_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec_Clears_Clip_Value;
   end Paste_Execution_Clears_Clipboard;

   function Paste_Execution_Cancelled
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec_Cancelled_Value;
   end Paste_Execution_Cancelled;

   function Paste_Execution_Cursor
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec_Cursor_Value;
   end Paste_Execution_Cursor;

   function Paste_Execution_Action_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Paste_Exec_Actions_Value.Length);
   end Paste_Execution_Action_Count;

   function Paste_Execution_Action
     (Model : Window_Model;
      Index : Positive)
      return Files.Paste.Resolved_Action is
   begin
      return Model.Paste_Exec_Actions_Value.Element (Index);
   end Paste_Execution_Action;

   function Paste_Execution_Undo_From
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Undo_From_Value;
   end Paste_Execution_Undo_From;

   function Paste_Execution_Undo_To
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Undo_To_Value;
   end Paste_Execution_Undo_To;

   function Paste_Execution_Replaced_Trash
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Replaced_Trash_Value;
   end Paste_Execution_Replaced_Trash;

   procedure Record_Paste_Execution_Replaced_Trash
     (Model      : in out Window_Model;
      Trash_Path : Files.Types.UString) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Replaced_Trash_Value.Append (Trash_Path);
   end Record_Paste_Execution_Replaced_Trash;

   function Paste_Execution_First_Dest
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Paste_Exec_First_Dest_Value);
   end Paste_Execution_First_Dest;

   procedure Skip_Paste_Execution_Action
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Cursor_Value := Model.Paste_Exec_Cursor_Value + 1;
   end Skip_Paste_Execution_Action;

   procedure Record_Paste_Execution_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Cursor_Value := Model.Paste_Exec_Cursor_Value + 1;
      Model.Paste_Exec_Done_Value := Model.Paste_Exec_Done_Value + 1;
      Model.Paste_Exec_Current_Value := To_Unbounded_String (Name);
      if Length (Model.Paste_Exec_First_Dest_Value) = 0 then
         Model.Paste_Exec_First_Dest_Value := Dest_Path;
      end if;
      Model.Paste_Exec_Undo_From_Value.Append (Dest_Path);
      Model.Paste_Exec_Undo_To_Value.Append (Source_Path);
   end Record_Paste_Execution_Write;

   procedure Cancel_Paste_Execution
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Cancelled_Value := True;
   end Cancel_Paste_Execution;

   procedure Clear_Paste_Execution
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Active_Value := False;
      Model.Paste_Exec_Actions_Value.Clear;
      Model.Paste_Exec_Cursor_Value := 0;
      Model.Paste_Exec_Done_Value := 0;
      Model.Paste_Exec_Total_Value := 0;
      Model.Paste_Exec_Mode_Value := Files.File_System.Drop_Copy;
      Model.Paste_Exec_Clears_Clip_Value := True;
      Model.Paste_Exec_Cancelled_Value := False;
      Model.Paste_Exec_Current_Value := Null_Unbounded_String;
      Model.Paste_Exec_First_Dest_Value := Null_Unbounded_String;
      Model.Paste_Exec_Undo_From_Value.Clear;
      Model.Paste_Exec_Undo_To_Value.Clear;
   end Clear_Paste_Execution;

end Files.Model.Paste_Exec;
