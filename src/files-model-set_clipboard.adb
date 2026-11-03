separate (Files.Model)
procedure Set_Clipboard
  (Model : in out Window_Model;
   Paths : Files.Types.String_Vectors.Vector;
   Mode  : Clipboard_Mode) is
begin
   Touch (Model);
   Model.Clipboard_Paths_Value := Paths;
   Model.Clipboard_Mode_Value :=
     (if Paths.Is_Empty then Clipboard_None else Mode);
end Set_Clipboard;
