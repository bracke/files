with Files.Model.Support;

package body Files.Model.Clipboard is

   use Ada.Strings.Unbounded;
   use Files.Model.Support;

   --  Only a cut marks rows (their Cut_Pending flag); a copy shows nowhere
   --  in the rows, so it moves the header revision alone.
   --  @param Model Model whose clipboard is about to change.
   --  @param New_Mode The clipboard mode after the change.
   procedure Touch_For_Mode
     (Model    : in out Window_Model;
      New_Mode : Clipboard_Mode) is
   begin
      if Model.Clipboard.Mode = Clipboard_Cut or else New_Mode = Clipboard_Cut then
         Touch (Model);
      else
         Touch_Header (Model);
      end if;
   end Touch_For_Mode;

   procedure Set
     (Model : in out Window_Model;
      Paths : Files.Types.String_Vectors.Vector;
      Mode  : Clipboard_Mode) is
      New_Mode : constant Clipboard_Mode := (if Paths.Is_Empty then Clipboard_None else Mode);
   begin
      Touch_For_Mode (Model, New_Mode);
      Model.Clipboard.Paths := Paths;
      Model.Clipboard.Mode := New_Mode;
   end Set;

   procedure Clear
     (Model : in out Window_Model) is
   begin
      Touch_For_Mode (Model, Clipboard_None);
      Model.Clipboard.Paths.Clear;
      Model.Clipboard.Mode := Clipboard_None;
   end Clear;

   function Paths
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
     (Model.Clipboard.Paths);

   function Mode_Of
     (Model : Window_Model)
      return Clipboard_Mode is
     (Model.Clipboard.Mode);

   function Has_Items
     (Model : Window_Model)
      return Boolean is
     (not Model.Clipboard.Paths.Is_Empty
       and then Model.Clipboard.Mode /= Clipboard_None);

   procedure Set_System_Request
     (Model : in out Window_Model;
      Text  : String) is
   begin
      Touch_Header (Model);
      Model.Clipboard.System_Request := To_Unbounded_String (Text);
      Model.Clipboard.System_Request_Pending := True;
   end Set_System_Request;

   function System_Request_Pending
     (Model : Window_Model)
      return Boolean is
     (Model.Clipboard.System_Request_Pending);

   function System_Request_Text
     (Model : Window_Model)
      return String is
     (To_String (Model.Clipboard.System_Request));

   procedure Clear_System_Request
     (Model : in out Window_Model) is
   begin
      Touch_Header (Model);
      Model.Clipboard.System_Request := Null_Unbounded_String;
      Model.Clipboard.System_Request_Pending := False;
   end Clear_System_Request;

end Files.Model.Clipboard;
