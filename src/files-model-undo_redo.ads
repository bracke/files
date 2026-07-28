with Files.Types;

--  The undo redo state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Undo_Redo is

   --  Push a newly performed undoable action onto the undo stack and clear the
   --  redo stack (a new operation invalidates any pending redo). Empty actions
   --  (Undo_None or no From paths) are ignored.
   --
   --  @param Model       Model to update.
   --  @param Kind        Kind of action that can be undone.
   --  @param From        Current locations to undo from (parallel to To).
   --  @param To          Restore targets / old values (reverse payload).
   --  @param Forward     Redo payload: source paths or new values; may be empty.
   --  @param Create_Kind Creation kind re-run for Undo_Delete_Created redo.
   --  @param Redoable    False marks the entry undo-only (skipped by redo).
   --  @param Restore_Trash Trash locations of paste-replace originals to restore
   --    from the trash after the main reverse; empty for non-replacing actions.
   procedure Record_Undo
     (Model       : in out Window_Model;
      Kind        : Undo_Action_Kind;
      From        : Files.Types.String_Vectors.Vector;
      To          : Files.Types.String_Vectors.Vector;
      Forward     : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector;
      Create_Kind : Undo_Create_Kind := Create_None;
      Redoable    : Boolean := True;
      Restore_Trash : Files.Types.String_Vectors.Vector :=
        Files.Types.String_Vectors.Empty_Vector);

   --  Forget the entire undo and redo history.
   --
   --  @param Model Model to update.
   procedure Clear_Undo
     (Model : in out Window_Model);

   --  Return whether an undoable action is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the undo stack is non-empty.
   function Undo_Available
     (Model : Window_Model)
      return Boolean;

   --  Return whether a redoable action is available.
   --
   --  @param Model Model to inspect.
   --  @return True when the redo stack is non-empty.
   function Redo_Available
     (Model : Window_Model)
      return Boolean;

   --  Pop the top entry off the undo stack.
   --
   --  @param Model  Model to update.
   --  @param Action Popped action; a default entry when Found is False.
   --  @param Found  True when an entry was popped.
   procedure Take_Undo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean);

   --  Pop the top entry off the redo stack.
   --
   --  @param Model  Model to update.
   --  @param Action Popped action; a default entry when Found is False.
   --  @param Found  True when an entry was popped.
   procedure Take_Redo
     (Model  : in out Window_Model;
      Action : out Undo_Entry;
      Found  : out Boolean);

   --  Push an action onto the redo stack (after a successful undo).
   --
   --  @param Model  Model to update.
   --  @param Action Action to push.
   procedure Push_Redo
     (Model  : in out Window_Model;
      Action : Undo_Entry);

   --  Push an action back onto the undo stack (after a successful redo),
   --  leaving the redo stack untouched.
   --
   --  @param Model  Model to update.
   --  @param Action Action to push.
   procedure Push_Undo
     (Model  : in out Window_Model;
      Action : Undo_Entry);

   --  Return the kind of the top undo entry.
   --
   --  @param Model Model to inspect.
   --  @return Undo_None when the undo stack is empty.
   function Undo_Kind_Of
     (Model : Window_Model)
      return Undo_Action_Kind;

   --  Return the top undo entry's "from" (current) paths.
   --
   --  @param Model Model to inspect.
   --  @return Vector of current locations, parallel to Undo_To_Paths.
   function Undo_From_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Return the top undo entry's "to" (restore-target) paths.
   --
   --  @param Model Model to inspect.
   --  @return Vector of restore targets, parallel to Undo_From_Paths.
   function Undo_To_Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

end Files.Model.Undo_Redo;
