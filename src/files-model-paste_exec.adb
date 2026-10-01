with Ada.Directories;
with Files.File_Identities;
with Hostkit.Fs;

separate (Files.Model)
package body Paste_Exec is
   use type Files.File_System.Drop_Import_Mode;

   function Identity_Matches (Path, Expected : String) return Boolean is
   begin
      return Expected /= ""
        and then (Ada.Directories.Exists (Path) or else Hostkit.Fs.Is_Link (Path))
        and then Files.File_Identities.Token (Path) = Expected;
   exception
      when others =>
         return False;
   end Identity_Matches;

   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String) return Boolean
   is
      use type Ada.Directories.File_Kind;
      Is_Link : Boolean;
   begin
      if not Identity_Matches (Path, Identity) then
         return False;
      end if;
      Is_Link := Hostkit.Fs.Is_Link (Path);
      return
        (if Is_Link then Tree_Revision = ""
         else Tree_Revision /= ""
           and then Files.File_System.Tree_Revision (Path) = Tree_Revision);
   exception
      when others =>
         return False;
   end Creation_Snapshot_Matches;

   procedure Begin_Paste_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True)
   is
      Writes : Natural := 0;
   begin
      Files.Transfer_Jobs.Reset (Model.Paste_Exec_Job);
      Files.Process_Jobs.Reset (Model.Operation_Job);
      Files.Process_Jobs.Reset (Model.Refresh_Job);
      Model.Operation_Label_Key := Null_Unbounded_String;
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
      Model.Paste_Exec_Copy_Context :=
        (if Writes > 1 then Files.Copy_Context.Create else Files.Copy_Context.Empty_Session);
      Model.Paste_Exec_Mode_Value := Mode;
      Model.Paste_Exec_Clears_Clip_Value := Clear_Clipboard;
      Model.Paste_Exec_Cancelled_Value := False;
      Model.Paste_Exec_Current_Value := Null_Unbounded_String;
      Model.Paste_Exec_First_Dest_Value := Null_Unbounded_String;
      Model.Paste_Exec_Undo_From_Value.Clear;
      Model.Paste_Exec_Undo_To_Value.Clear;
      Model.Paste_Exec_Identities_Value.Clear;
      Model.Paste_Exec_Tree_Revisions_Value.Clear;
      Model.Paste_Exec_Verified_Created_Count := 0;
      Model.Paste_Exec_Replaced_Trash_Value.Clear;
      Model.Paste_Exec_Replaced_Identities_Value.Clear;
      Model.Paste_Exec_Replaced_Targets_Value.Clear;
      Model.Paste_Exec_Verified_Replaced_Count := 0;
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

   function Paste_Execution_Created_Identities
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Identities_Value;
   end Paste_Execution_Created_Identities;

   function Paste_Execution_Created_Tree_Revisions
     (Model : Window_Model) return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Tree_Revisions_Value;
   end Paste_Execution_Created_Tree_Revisions;

   function Paste_Execution_Verified_Created_Count
     (Model : Window_Model) return Natural is
   begin
      return Model.Paste_Exec_Verified_Created_Count;
   end Paste_Execution_Verified_Created_Count;

   function Paste_Execution_Replaced_Trash
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Replaced_Trash_Value;
   end Paste_Execution_Replaced_Trash;

   function Paste_Execution_Replaced_Identities
     (Model : Window_Model) return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Replaced_Identities_Value;
   end Paste_Execution_Replaced_Identities;

   function Paste_Execution_Replaced_Targets
     (Model : Window_Model) return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec_Replaced_Targets_Value;
   end Paste_Execution_Replaced_Targets;

   function Paste_Execution_Verified_Replaced_Count
     (Model : Window_Model) return Natural is
   begin
      return Model.Paste_Exec_Verified_Replaced_Count;
   end Paste_Execution_Verified_Replaced_Count;

   function Paste_Execution_Copy_Context (Model : Window_Model) return Files.Copy_Context.Session is
     (Model.Paste_Exec_Copy_Context);

   procedure Record_Paste_Execution_Replaced_Trash
     (Model      : in out Window_Model;
      Trash_Path : Files.Types.UString;
      Identity : String;
      Original_Path : String := "") is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Replaced_Trash_Value.Append (Trash_Path);
      Model.Paste_Exec_Replaced_Identities_Value.Append (To_Unbounded_String (Identity));
      Model.Paste_Exec_Replaced_Targets_Value.Append (To_Unbounded_String
        (if Original_Path /= "" then Original_Path
         else Files.File_System.Trash_Original_Path (To_String (Trash_Path))));
      if Model.Paste_Exec_Verified_Replaced_Count + 1 =
           Natural (Model.Paste_Exec_Replaced_Trash_Value.Length)
        and then Identity_Matches (To_String (Trash_Path), Identity)
      then
         Model.Paste_Exec_Verified_Replaced_Count :=
           Model.Paste_Exec_Verified_Replaced_Count + 1;
      end if;
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
      Name        : String;
      Identity    : String;
      Tree_Revision : String;
      Retain_Verified_Snapshot : Boolean := False) is
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
      Model.Paste_Exec_Identities_Value.Append
        (To_Unbounded_String (Identity));
      Model.Paste_Exec_Tree_Revisions_Value.Append
        (To_Unbounded_String (Tree_Revision));
      if Model.Paste_Exec_Verified_Created_Count + 1 =
           Natural (Model.Paste_Exec_Undo_From_Value.Length)
        and then
          ((Retain_Verified_Snapshot and then Identity /= "")
           or else
             (if Model.Paste_Exec_Mode_Value = Files.File_System.Drop_Move
              then Identity_Matches (To_String (Dest_Path), Identity)
              else Creation_Snapshot_Matches
                (To_String (Dest_Path), Identity, Tree_Revision)))
      then
         Model.Paste_Exec_Verified_Created_Count :=
           Model.Paste_Exec_Verified_Created_Count + 1;
      end if;
   end Record_Paste_Execution_Write;

   procedure Cancel_Paste_Execution
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Cancelled_Value := True;
      Files.Transfer_Jobs.Cancel (Model.Paste_Exec_Job);
      Files.Process_Jobs.Cancel (Model.Operation_Job);
   end Cancel_Paste_Execution;

   procedure Clear_Paste_Execution
     (Model : in out Window_Model) is
   begin
      Files.Transfer_Jobs.Reset (Model.Paste_Exec_Job);
      Files.Process_Jobs.Reset (Model.Operation_Job);
      Model.Operation_Label_Key := Null_Unbounded_String;
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec_Active_Value := False;
      Model.Paste_Exec_Actions_Value.Clear;
      Model.Paste_Exec_Cursor_Value := 0;
      Model.Paste_Exec_Done_Value := 0;
      Model.Paste_Exec_Total_Value := 0;
      Model.Paste_Exec_Mode_Value := Files.File_System.Drop_Copy;
      Model.Paste_Exec_Copy_Context := Files.Copy_Context.Empty_Session;
      Model.Paste_Exec_Clears_Clip_Value := True;
      Model.Paste_Exec_Cancelled_Value := False;
      Model.Paste_Exec_Current_Value := Null_Unbounded_String;
      Model.Paste_Exec_First_Dest_Value := Null_Unbounded_String;
      Model.Paste_Exec_Undo_From_Value.Clear;
      Model.Paste_Exec_Undo_To_Value.Clear;
      Model.Paste_Exec_Identities_Value.Clear;
      Model.Paste_Exec_Tree_Revisions_Value.Clear;
      Model.Paste_Exec_Verified_Created_Count := 0;
      Model.Paste_Exec_Replaced_Trash_Value.Clear;
      Model.Paste_Exec_Replaced_Identities_Value.Clear;
      Model.Paste_Exec_Replaced_Targets_Value.Clear;
      Model.Paste_Exec_Verified_Replaced_Count := 0;
   end Clear_Paste_Execution;

end Paste_Exec;
