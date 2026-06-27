with Files.Events;
with Files.File_System;
with Files.Model;
with Files.Rendering;
with Files.Types;

package Files_Suite.Support is

   Root : constant String := "/tmp/files_aunit";

   function Click_Action
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Activate    : Boolean := False;
      Modifiers   : Files.Types.Modifier_Set := Files.Types.No_Modifiers;
      Line_Height : Positive := 20)
      return Files.Events.Input_Action;

   function Create_Symlink (Target : String; Linkpath : String) return Boolean;

   procedure Reset_Root;

   procedure Write_File (Path : String; Content : String := "x");

   procedure Write_Binary_File (Path : String; Content : String);

   function Byte (Value : Natural) return Character;

   function Minimal_Png_Header (Width : Natural; Height : Natural) return String;

   function Stored_Zlib_Stream (Payload : String) return String;

   function Chunk (Kind : String; Data : String) return String;

   function Minimal_Png_RGB
     (Width   : Natural;
      Height  : Natural;
      Payload : String)
      return String;

   function Minimal_Jpeg_With_Fill (Width : Natural; Height : Natural) return String;

   function Join (Parent : String; Name : String) return String;

   function Sample_Items return Files.File_System.Item_Vectors.Vector;

   function Sample_Model return Files.Model.Window_Model;

   procedure Select_Name (Model : in out Files.Model.Window_Model; Name : String);

end Files_Suite.Support;
