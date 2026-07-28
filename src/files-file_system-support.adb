with Ada.Environment_Variables;

package body Files.File_System.Support is

   procedure Safe_End_Search
     (Search  : in out Ada.Directories.Search_Type;
      Started : in out Boolean) is
   begin
      if Started then
         begin
            Ada.Directories.End_Search (Search);
         exception
            when others =>
               null;
         end;
         Started := False;
      end if;
   end Safe_End_Search;

   procedure Safe_Close
     (File : in out Ada.Text_IO.File_Type) is
   begin
      if Ada.Text_IO.Is_Open (File) then
         begin
            Ada.Text_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   procedure Safe_Close
     (File : in out Ada.Streams.Stream_IO.File_Type) is
   begin
      if Ada.Streams.Stream_IO.Is_Open (File) then
         begin
            Ada.Streams.Stream_IO.Close (File);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Close;

   function Safe_Environment_Value
     (Name : String)
      return String is
   begin
      if Ada.Environment_Variables.Exists (Name) then
         return Ada.Environment_Variables.Value (Name);
      end if;

      return "";
   exception
      when others =>
         return "";
   end Safe_Environment_Value;

   function Environment_Equals
     (Name     : String;
      Expected : String)
      return Boolean is
   begin
      return Files.Types.To_Lower (Safe_Environment_Value (Name)) = Expected;
   end Environment_Equals;

   function Image_No_Space (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Image_No_Space;

   function Starts_With
     (Value  : String;
      Prefix : String)
      return Boolean is
   begin
      return Value'Length >= Prefix'Length
        and then Value (Value'First .. Value'First + Prefix'Length - 1) = Prefix;
   end Starts_With;

   function Natural_Text (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      if Image'Length > 0 and then Image (Image'First) = ' ' then
         return Image (Image'First + 1 .. Image'Last);
      end if;

      return Image;
   end Natural_Text;

end Files.File_System.Support;
