with Ada.Strings.Unbounded;
with Files.Background_Slots;
with Files.File_System;

package body Files.Extra_Info_Reader is
   use Ada.Strings.Unbounded;

   type Item_Facts is record
      Kind     : Files.Types.Item_Kind := Files.Types.Unknown_Item;
      Filetype : Unbounded_String;
   end record;

   function Read (Path : String; Facts : Item_Facts) return Files.Extra_Info.Info is
     (Files.File_System.Extra_Info_Of (Path, Facts.Kind, To_String (Facts.Filetype)));

   --  Every answer, an empty one included, is handed out once: the model
   --  records it as loaded and does not ask again.
   function Always (Extra : Files.Extra_Info.Info) return Boolean is
      pragma Unreferenced (Extra);
   begin
      return True;
   end Always;

   function No_Details return Files.Extra_Info.Info is (Files.Extra_Info.No_Info);

   package Reader is new Files.Background_Slots
     (Parameters  => Item_Facts,
      Result      => Files.Extra_Info.Info,
      Work        => Read,
      Failed      => No_Details,
      Handed_Once => Always);

   procedure Request
     (Owner    : Requester;
      Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String) is
   begin
      Reader.Request (Reader.Requester (Owner), Path, (Kind => Kind, Filetype => To_Unbounded_String (Filetype)));
   end Request;

   procedure Take
     (Owner : Requester;
      Path  : String;
      Extra : out Files.Extra_Info.Info;
      Ready : out Boolean;
      Asked : out Boolean) is
   begin
      Reader.Take (Reader.Requester (Owner), Path, Extra, Ready, Asked);
   end Take;

end Files.Extra_Info_Reader;
