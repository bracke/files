with Ada.Directories;
with Files.File_Identities;
with Hostkit.Fs;

separate (Files.Model)
package body Paste_Exec is
   use type Files.File_System.Drop_Import_Mode;

   function Identity_Matches (Path, Expected : String) return Boolean
     renames Files.File_System.Entry_Identity_Matches;

   function Creation_Snapshot_Matches
     (Path, Identity, Tree_Revision : String;
      Retain_Verified : Boolean := False) return Boolean
     renames Files.File_System.Creation_Matches;

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
      Claim_Overlay_Input (Model);
      for Action of Actions loop
         if not Action.Skip then
            Writes := Writes + 1;
         end if;
      end loop;

      Model.Paste_Exec :=
        (Active           => True,
         Actions          => Actions,
         Total            => Writes,
         Copy_Context     =>
           (if Writes > 1 then Files.Copy_Context.Create else Files.Copy_Context.Empty_Session),
         Mode             => Mode,
         Clears_Clipboard => Clear_Clipboard,
         others           => <>);
   end Begin_Paste_Execution;

   function Paste_Execution_Is_Active
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec.Active;
   end Paste_Execution_Is_Active;

   function Paste_Execution_Done
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec.Done;
   end Paste_Execution_Done;

   function Paste_Execution_Total
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec.Total;
   end Paste_Execution_Total;

   function Paste_Execution_Current_Name
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Paste_Exec.Current);
   end Paste_Execution_Current_Name;

   function Paste_Execution_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode is
   begin
      return Model.Paste_Exec.Mode;
   end Paste_Execution_Mode;

   function Paste_Execution_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec.Clears_Clipboard;
   end Paste_Execution_Clears_Clipboard;

   function Paste_Execution_Cancelled
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Exec.Cancelled;
   end Paste_Execution_Cancelled;

   function Paste_Execution_Cursor
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Paste_Exec.Cursor;
   end Paste_Execution_Cursor;

   function Paste_Execution_Action_Count
     (Model : Window_Model)
      return Natural is
   begin
      return Natural (Model.Paste_Exec.Actions.Length);
   end Paste_Execution_Action_Count;

   function Paste_Execution_Action
     (Model : Window_Model;
      Index : Positive)
      return Files.Paste.Resolved_Action is
   begin
      return Model.Paste_Exec.Actions.Element (Index);
   end Paste_Execution_Action;

   function Paste_Execution_Undo_From
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec.Undo_From;
   end Paste_Execution_Undo_From;

   function Paste_Execution_Undo_To
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec.Undo_To;
   end Paste_Execution_Undo_To;

   function Paste_Execution_Created_Identities
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec.Identities;
   end Paste_Execution_Created_Identities;

   function Paste_Execution_Created_Tree_Revisions
     (Model : Window_Model) return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec.Tree_Revisions;
   end Paste_Execution_Created_Tree_Revisions;

   function Paste_Execution_Verified_Created_Count
     (Model : Window_Model) return Natural is
   begin
      return Model.Paste_Exec.Verified_Created_Count;
   end Paste_Execution_Verified_Created_Count;

   function Paste_Execution_Replaced_Trash
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec.Replaced_Trash;
   end Paste_Execution_Replaced_Trash;

   function Paste_Execution_Replaced_Identities
     (Model : Window_Model) return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec.Replaced_Identities;
   end Paste_Execution_Replaced_Identities;

   function Paste_Execution_Replaced_Targets
     (Model : Window_Model) return Files.Types.String_Vectors.Vector is
   begin
      return Model.Paste_Exec.Replaced_Targets;
   end Paste_Execution_Replaced_Targets;

   function Paste_Execution_Verified_Replaced_Count
     (Model : Window_Model) return Natural is
   begin
      return Model.Paste_Exec.Verified_Replaced_Count;
   end Paste_Execution_Verified_Replaced_Count;

   function Paste_Execution_Copy_Context (Model : Window_Model) return Files.Copy_Context.Session is
     (Model.Paste_Exec.Copy_Context);

   procedure Record_Paste_Execution_Replaced_Trash
     (Model      : in out Window_Model;
      Trash_Path : Files.Types.UString;
      Identity : String;
      Original_Path : String := "") is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec.Replaced_Trash.Append (Trash_Path);
      Model.Paste_Exec.Replaced_Identities.Append (To_Unbounded_String (Identity));
      Model.Paste_Exec.Replaced_Targets.Append (To_Unbounded_String
        (if Original_Path /= "" then Original_Path
         else Files.File_System.Trash_Original_Path (To_String (Trash_Path))));
      if Model.Paste_Exec.Verified_Replaced_Count + 1 =
           Natural (Model.Paste_Exec.Replaced_Trash.Length)
        and then Identity_Matches (To_String (Trash_Path), Identity)
      then
         Model.Paste_Exec.Verified_Replaced_Count :=
           Model.Paste_Exec.Verified_Replaced_Count + 1;
      end if;
   end Record_Paste_Execution_Replaced_Trash;

   function Paste_Execution_First_Dest
     (Model : Window_Model)
      return String is
   begin
      return To_String (Model.Paste_Exec.First_Dest);
   end Paste_Execution_First_Dest;

   procedure Skip_Paste_Execution_Action
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec.Cursor := Model.Paste_Exec.Cursor + 1;
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
      Model.Paste_Exec.Cursor := Model.Paste_Exec.Cursor + 1;
      Model.Paste_Exec.Done := Model.Paste_Exec.Done + 1;
      Model.Paste_Exec.Current := To_Unbounded_String (Name);
      if Length (Model.Paste_Exec.First_Dest) = 0 then
         Model.Paste_Exec.First_Dest := Dest_Path;
      end if;
      Model.Paste_Exec.Undo_From.Append (Dest_Path);
      Model.Paste_Exec.Undo_To.Append (Source_Path);
      Model.Paste_Exec.Identities.Append
        (To_Unbounded_String (Identity));
      Model.Paste_Exec.Tree_Revisions.Append
        (To_Unbounded_String (Tree_Revision));
      if Model.Paste_Exec.Verified_Created_Count + 1 =
           Natural (Model.Paste_Exec.Undo_From.Length)
        and then
          ((Retain_Verified_Snapshot and then Identity /= "")
           or else
             (if Model.Paste_Exec.Mode = Files.File_System.Drop_Move
              then Identity_Matches (To_String (Dest_Path), Identity)
              else Creation_Snapshot_Matches
                (To_String (Dest_Path), Identity, Tree_Revision)))
      then
         Model.Paste_Exec.Verified_Created_Count :=
           Model.Paste_Exec.Verified_Created_Count + 1;
      end if;
   end Record_Paste_Execution_Write;

   procedure Cancel_Paste_Execution
     (Model : in out Window_Model) is
      Requested : Boolean := True;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      --  Each cancel can fail (Process_Jobs refuses when it cannot write a
      --  trustworthy marker and stays retryable). Try both, and only show the
      --  operation as cancelled when both requests went through; otherwise the
      --  UI said "cancelled" while the helper ran to completion, and a second
      --  Cancel was never possible.
      begin
         Files.Transfer_Jobs.Cancel (Model.Paste_Exec_Job);
      exception
         when others => Requested := False;
      end;
      begin
         Files.Process_Jobs.Cancel (Model.Operation_Job);
      exception
         when others => Requested := False;
      end;
      Model.Paste_Exec.Cancelled := Requested;
   end Cancel_Paste_Execution;

   procedure Clear_Paste_Execution
     (Model : in out Window_Model) is
   begin
      Files.Transfer_Jobs.Reset (Model.Paste_Exec_Job);
      Files.Process_Jobs.Reset (Model.Operation_Job);
      Model.Operation_Label_Key := Null_Unbounded_String;
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Paste_Exec := (others => <>);
   end Clear_Paste_Execution;

end Paste_Exec;
