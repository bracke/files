--  The paste conflict state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Paste_Conflict is

   --  Enter the pending paste-conflict sub-mode. The work-list, the set of
   --  existing destination paths, and the copy/move mode are recorded, the
   --  policy starts at Policy_Ask with no per-item overrides, and the dialog is
   --  positioned at the first unresolved conflict (Index).
   --
   --  @param Model Model to update.
   --  @param Items Full paste work-list.
   --  @param Existing Destination paths that already exist.
   --  @param Mode Copy or move mode for the whole batch.
   --  @param Index One-based index of the first unresolved conflict.
   --  @param Clear_Clipboard Whether finalizing a move should clear the
   --    clipboard (True for clipboard paste, False for drag-and-drop).
   procedure Begin_Paste_Conflict
     (Model           : in out Window_Model;
      Items           : Files.Paste.Work_Item_Vectors.Vector;
      Existing        : Files.Types.String_Vectors.Vector;
      Mode            : Files.File_System.Drop_Import_Mode;
      Index           : Positive;
      Clear_Clipboard : Boolean := True);

   --  Whether the pending paste-conflict dialog is active.
   --
   --  @param Model Model to inspect.
   --  @return True while a paste is paused awaiting conflict decisions.
   function Paste_Conflict_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  The recorded paste work-list.
   --
   --  @param Model Model to inspect.
   --  @return The full work-list captured when the sub-mode began.
   function Paste_Conflict_Items
     (Model : Window_Model)
      return Files.Paste.Work_Item_Vectors.Vector;

   --  The recorded set of existing destination paths.
   --
   --  @param Model Model to inspect.
   --  @return Destination paths that existed when the sub-mode began.
   function Paste_Conflict_Existing
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  The accumulated per-item decisions, parallel to the work-list.
   --
   --  @param Model Model to inspect.
   --  @return Per-item overrides recorded so far.
   function Paste_Conflict_Overrides
     (Model : Window_Model)
      return Files.Paste.Item_Decision_Vectors.Vector;

   --  The accumulated batch-wide policy.
   --
   --  @param Model Model to inspect.
   --  @return The current conflict policy.
   function Paste_Conflict_Policy
     (Model : Window_Model)
      return Files.Paste.Conflict_Policy;

   --  The copy/move mode of the pending paste.
   --
   --  @param Model Model to inspect.
   --  @return Copy or move mode.
   function Paste_Conflict_Mode
     (Model : Window_Model)
      return Files.File_System.Drop_Import_Mode;

   --  Whether finalizing this paste's move should clear the clipboard.
   --
   --  @param Model Model to inspect.
   --  @return True for a clipboard-originated paste, False for drag-and-drop.
   function Paste_Conflict_Clears_Clipboard
     (Model : Window_Model)
      return Boolean;

   --  The one-based index of the conflict currently shown, or 0 when inactive.
   --
   --  @param Model Model to inspect.
   --  @return Index into the work-list of the conflict under decision.
   function Paste_Conflict_Index
     (Model : Window_Model)
      return Natural;

   --  The leaf name of the conflict currently shown.
   --
   --  @param Model Model to inspect.
   --  @return The colliding destination name, or "" when inactive.
   function Paste_Conflict_Name
     (Model : Window_Model)
      return String;

   --  Whether the dialog's "apply to all remaining" toggle is on.
   --
   --  @param Model Model to inspect.
   --  @return True when the next decision should apply to every remaining conflict.
   function Paste_Conflict_Apply_All
     (Model : Window_Model)
      return Boolean;

   --  Flip the dialog's "apply to all remaining" toggle.
   --
   --  @param Model Model to update.
   procedure Toggle_Paste_Conflict_Apply_All
     (Model : in out Window_Model);

   --  Record the batch-wide policy (used when a decision is applied to all).
   --
   --  @param Model Model to update.
   --  @param Policy New conflict policy.
   procedure Set_Paste_Conflict_Policy
     (Model  : in out Window_Model;
      Policy : Files.Paste.Conflict_Policy);

   --  Record a per-item decision for one work-list index.
   --
   --  @param Model Model to update.
   --  @param Index One-based work-list index.
   --  @param Decision Chosen per-item decision.
   procedure Set_Paste_Conflict_Override
     (Model    : in out Window_Model;
      Index    : Positive;
      Decision : Files.Paste.Item_Decision);

   --  Move the dialog to a different conflict index.
   --
   --  @param Model Model to update.
   --  @param Index One-based work-list index of the next conflict.
   procedure Set_Paste_Conflict_Index
     (Model : in out Window_Model;
      Index : Positive);

   --  Clear the pending paste-conflict sub-mode, discarding its state.
   --
   --  @param Model Model to update.
   procedure Clear_Paste_Conflict
     (Model : in out Window_Model);

end Files.Model.Paste_Conflict;
