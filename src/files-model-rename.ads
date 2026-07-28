--  The rename state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Rename is

   --  Focus the active rename input without changing its existing text.
   --
   --  @param Model Model to update.
   procedure Focus_Rename_Input
     (Model : in out Window_Model);

   --  Return whether rename can start for the current selection.
   --
   --  @param Model Model to inspect.
   --  @return True when at least one non-temporary item is selected.
   function Rename_Is_Enabled
     (Model : Window_Model)
      return Boolean;

   --  Return the rename policy selected by this implementation.
   --
   --  @return Rename behavior policy.
   function Rename_Behavior return Rename_Policy;

   --  Toggle synchronized multi-item rename mode.
   --
   --  When starting, one inline rename field is created per selected loaded
   --  item, each with its caret placed before the file extension.
   --
   --  @param Model Model to update.
   procedure Toggle_Rename
     (Model : in out Window_Model);

   --  Return whether rename mode is active.
   --
   --  @param Model Model to inspect.
   --  @return True when rename mode is active.
   function Rename_Is_Active
     (Model : Window_Model)
      return Boolean;

   --  Return the number of active inline rename fields.
   --
   --  @param Model Model to inspect.
   --  @return Count of rename fields (zero when rename is inactive).
   function Rename_Field_Count
     (Model : Window_Model)
      return Natural;

   --  Return the first rename field's text (a shim for single-field callers).
   --
   --  @param Model Model to inspect.
   --  @return First field's rename text, or an empty string.
   function Rename_Text
     (Model : Window_Model)
      return String;

   --  Set the first rename field's text (a shim for single-field callers).
   --
   --  @param Model Model to update.
   --  @param Text New rename text for the first field.
   procedure Set_Rename_Text
     (Model : in out Window_Model;
      Text  : String);

   --  Insert Text at every rename field's caret, advancing each caret.
   --
   --  @param Model Model to update.
   --  @param Text UTF-8 text to insert.
   --  @return True when any field changed.
   function Rename_Insert_At_Carets
     (Model : in out Window_Model;
      Text  : String)
      return Boolean;

   --  Delete the character before every rename field's caret.
   --
   --  @param Model Model to update.
   --  @return True when any field changed.
   function Rename_Delete_Backward
     (Model : in out Window_Model)
      return Boolean;

   --  Delete the character at every rename field's caret.
   --
   --  @param Model Model to update.
   --  @return True when any field changed.
   function Rename_Delete_Forward
     (Model : in out Window_Model)
      return Boolean;

   --  Delete the word before every rename field's caret.
   --
   --  @param Model Model to update.
   --  @return True when any field changed.
   function Rename_Delete_Word_Backward
     (Model : in out Window_Model)
      return Boolean;

   --  Delete the word at every rename field's caret.
   --
   --  @param Model Model to update.
   --  @return True when any field changed.
   function Rename_Delete_Word_Forward
     (Model : in out Window_Model)
      return Boolean;

   --  Move every rename field's caret one text boundary in Direction.
   --
   --  @param Model Model to update.
   --  @param Direction Left/Up moves back, Right/Down moves forward.
   --  @return True when any caret moved.
   function Rename_Move_All_Carets
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean;

   --  Move every rename field's caret one word boundary in Direction.
   --
   --  @param Model Model to update.
   --  @param Direction Left/Up moves back, Right/Down moves forward.
   --  @return True when any caret moved.
   function Rename_Move_All_Carets_Word
     (Model     : in out Window_Model;
      Direction : Guikit.Input.Navigation_Direction)
      return Boolean;

   --  Move every rename field's caret to the start of its text.
   --
   --  @param Model Model to update.
   --  @return True when any caret moved.
   function Rename_Set_All_Carets_Home
     (Model : in out Window_Model)
      return Boolean;

   --  Move every rename field's caret to the end of its text.
   --
   --  @param Model Model to update.
   --  @return True when any caret moved.
   function Rename_Set_All_Carets_End
     (Model : in out Window_Model)
      return Boolean;

   --  Set the caret of the rename field shown at Visible_Index only.
   --
   --  @param Model Model to update.
   --  @param Visible_Index One-based visible row index of the clicked field.
   --  @param Position Byte offset of the new caret (clamped to a boundary).
   procedure Set_Rename_Caret
     (Model         : in out Window_Model;
      Visible_Index : Natural;
      Position      : Natural);

   --  Return the rename state for the item shown at Visible_Index.
   --
   --  @param Model Model to inspect.
   --  @param Visible_Index One-based visible row index.
   --  @param Active Set True when that row has an active rename field.
   --  @param Value Field text (empty when inactive).
   --  @param Cursor Field caret byte offset (zero when inactive).
   procedure Rename_State_For_Visible
     (Model         : Window_Model;
      Visible_Index : Positive;
      Active        : out Boolean;
      Value         : out UString;
      Cursor        : out Natural);

   --  Return the commit targets for the active real-item rename fields.
   --
   --  @param Model Model to inspect.
   --  @return One target per real rename field (temporary fields excluded).
   function Rename_Targets
     (Model : Window_Model)
      return Rename_Target_Vectors.Vector;

   --  Resume single-item rename mode for the currently selected item.
   --
   --  @param Model Model to update.
   --  @param Text Rename text to restore.
   procedure Resume_Rename
     (Model : in out Window_Model;
      Text  : String);

end Files.Model.Rename;
