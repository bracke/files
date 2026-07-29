separate (Files.Model)
   function Paste_Conflict_Clears_Clipboard
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Paste_Conflict_Clears_Clip_Val;
   end Paste_Conflict_Clears_Clipboard;
