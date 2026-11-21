with Files.Model.Support;
with Files.Undo.History;

package body Files.Model.Pasting is

   use Ada.Strings.Unbounded;
   use Files.Model.Support;

   procedure Begin_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System_Types.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True) is
   begin
      Touch (Model);
      Claim_Overlay_Input (Model);
      Model.Paste_Conflict :=
        (Active           => True,
         Items            => Items,
         Existing         => Existing,
         Mode             => Mode,
         Clears_Clipboard => Clear_Clipboard,
         Index            => Index,
         others           => <>);
      for Ignore in Items.First_Index .. Items.Last_Index loop
         Model.Paste_Conflict.Overrides.Append (Files.Paste.Decision_Pending);
      end loop;
   end Begin_Conflict;

   function Conflict_Of (Model : Window_Model) return Files.Paste_States.Conflict_State is (Model.Paste_Conflict);

   function Conflict_Is_Active
     (Model : Window_Model)
      return Boolean is
     (Model.Paste_Conflict.Active);

   function Conflict_Name
     (Model : Window_Model)
      return String is
   begin
      if Model.Paste_Conflict.Active
        and then Model.Paste_Conflict.Index
                 in Model.Paste_Conflict.Items.First_Index
                    .. Model.Paste_Conflict.Items.Last_Index
      then
         return To_String
           (Model.Paste_Conflict.Items.Element
              (Model.Paste_Conflict.Index).Dest_Name);
      end if;
      return "";
   end Conflict_Name;

   function Conflict_Apply_All
     (Model : Window_Model)
      return Boolean is
     (Model.Paste_Conflict.Apply_All);

   procedure Toggle_Conflict_Apply_All
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Paste_Conflict.Apply_All := not Model.Paste_Conflict.Apply_All;
   end Toggle_Conflict_Apply_All;

   procedure Set_Conflict_Policy
     (Model  : in out Window_Model;
      Policy : Files.Paste.Conflict_Policy) is
   begin
      Touch (Model);
      Model.Paste_Conflict.Policy := Policy;
   end Set_Conflict_Policy;

   procedure Set_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision) is
   begin
      Touch (Model);
      if Index <= Natural (Model.Paste_Conflict.Overrides.Length) then
         Model.Paste_Conflict.Overrides.Replace_Element (Index, Decision);
      end if;
   end Set_Conflict_Override;

   procedure Set_Conflict_Index
     (Model : in out Window_Model;
      Index : Positive) is
   begin
      Touch (Model);
      Model.Paste_Conflict.Index := Index;
   end Set_Conflict_Index;

   procedure Clear_Conflict
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Paste_Conflict := (others => <>);
   end Clear_Conflict;

   procedure Begin_Execution
     (Model           : in out Window_Model;
      Actions         : Files.Paste.Resolved_Action_Vectors.Vector;
      Mode            : Files.File_System_Types.Drop_Import_Mode;
      Clear_Clipboard : Boolean := True;
      Batch           : Files.Jobs.Copy_Context.Session := Files.Jobs.Copy_Context.Empty_Session)
   is
      Writes : Natural := 0;
   begin
      --  The previous helpers' handles are released (End_Foreground_Job).
      End_Foreground_Job (Model);
      Model.Refresh_Job := Released_Process;
      Model.Foreground_Kind := Paste_Job;
      Touch (Model);
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
         Copy_Context     => Batch,
         Mode             => Mode,
         Clears_Clipboard => Clear_Clipboard,
         others           => <>);
   end Begin_Execution;

   function Execution_Of (Model : Window_Model) return Files.Paste_States.Execution_State is (Model.Paste_Exec);

   function Job (Model : Window_Model) return Files.Jobs.Transfer.Session is (Model.Paste_Exec_Job);

   procedure Set_Job (Model : in out Window_Model; Job : Files.Jobs.Transfer.Session) is
   begin
      Model.Paste_Exec_Job := Job;
   end Set_Job;

   procedure Note_Action_Started (Model : in out Window_Model) is
   begin
      Model.Paste_Exec.Current :=
        To_Unbounded_String
          (Files.Types.Leaf_Of
             (To_String (Model.Paste_Exec.Actions.Element (Model.Paste_Exec.Cursor + 1).Source_Path)));
      Support.Touch_Header (Model);
   end Note_Action_Started;

   function Execution_Is_Active
     (Model : Window_Model)
      return Boolean is
     (Model.Paste_Exec.Active);

   function Execution_Mode
     (Model : Window_Model)
      return Files.File_System_Types.Drop_Import_Mode is
     (Model.Paste_Exec.Mode);

   function Execution_Cancelled
     (Model : Window_Model)
      return Boolean is
     (Model.Paste_Exec.Cancelled);

   function Execution_Cursor
     (Model : Window_Model)
      return Natural is
     (Model.Paste_Exec.Cursor);

   function Execution_Action_Count
     (Model : Window_Model)
      return Natural is
     (Natural (Model.Paste_Exec.Actions.Length));

   function Execution_Action
     (Model : Window_Model;
      Index : Positive)
      return Files.Paste.Resolved_Action is
     (Model.Paste_Exec.Actions.Element (Index));

   function Execution_Copy_Context (Model : Window_Model) return Files.Jobs.Copy_Context.Session is
     (Model.Paste_Exec.Copy_Context);

   procedure Record_Replaced_Trash
     (Model      : in out Window_Model;
      Trash_Path : Files.Types.UString;
      Identity : String;
      Original_Path : String;
      Verified : Boolean) is
   begin
      Touch (Model);
      Model.Paste_Exec.Replaced.Append
        (Files.Undo.History.Recorded_Original'
           (Original   =>
              (Trash    => Trash_Path,
               Identity => To_Unbounded_String (Identity),
               Target   => To_Unbounded_String (Original_Path)),
            Provenance => (if Verified then Files.Undo.History.Verified else Files.Undo.History.Published)));
   end Record_Replaced_Trash;

   procedure Skip_Action
     (Model : in out Window_Model) is
   begin
      Touch_Header (Model);
      Model.Paste_Exec.Cursor := Model.Paste_Exec.Cursor + 1;
   end Skip_Action;

   procedure Record_Write
     (Model       : in out Window_Model;
      Dest_Path   : Files.Types.UString;
      Source_Path : Files.Types.UString;
      Name        : String;
      Identity    : String;
      Tree_Revision : String;
      Verified    : Boolean) is
   begin
      Touch_Header (Model);
      Model.Paste_Exec.Cursor := Model.Paste_Exec.Cursor + 1;
      Model.Paste_Exec.Done := Model.Paste_Exec.Done + 1;
      Model.Paste_Exec.Current := To_Unbounded_String (Name);
      if Length (Model.Paste_Exec.First_Dest) = 0 then
         Model.Paste_Exec.First_Dest := Dest_Path;
      end if;
      Model.Paste_Exec.Written.Append
        (Files.Undo.History.Recorded_Item'
           (Item       =>
              (From          => Dest_Path,
               To            => Source_Path,
               Identity      => To_Unbounded_String (Identity),
               Tree_Revision => To_Unbounded_String (Tree_Revision),
               others        => <>),
            Provenance => (if Verified then Files.Undo.History.Verified else Files.Undo.History.Published)));
   end Record_Write;

   procedure Set_Cancelled
     (Model     : in out Window_Model;
      Requested : Boolean) is
   begin
      Support.Touch (Model);
      Model.Paste_Exec.Cancelled := Requested;
   end Set_Cancelled;

end Files.Model.Pasting;
