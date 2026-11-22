with Ada.Strings.Unbounded;

package body Files.Text_Basics is

   function Split_Path_List (List : String; Separator : Character) return Files.Types.String_Vectors.Vector is
      Result : Files.Types.String_Vectors.Vector;
      First  : Integer := List'First;
   begin
      for Index in List'Range loop
         if List (Index) = Separator then
            Result.Append (Ada.Strings.Unbounded.To_Unbounded_String (List (First .. Index - 1)));
            First := Index + 1;
         end if;
      end loop;
      Result.Append (Ada.Strings.Unbounded.To_Unbounded_String (List (First .. List'Last)));
      return Result;
   end Split_Path_List;

   function Trim_Blanks (Text : String) return String is
      First : Integer := Text'First;
      Last  : Integer := Text'Last;

      function Blank (Value : Character) return Boolean is
        (Value = ' ' or else Value = ASCII.HT or else Value = ASCII.CR);
   begin
      while First <= Last and then Blank (Text (First)) loop
         First := First + 1;
      end loop;
      while Last >= First and then Blank (Text (Last)) loop
         Last := Last - 1;
      end loop;
      return Text (First .. Last);
   end Trim_Blanks;

   function Natural_Text (Value : Natural) return String is
      Image : constant String := Natural'Image (Value);
   begin
      return Image (Image'First + 1 .. Image'Last);
   end Natural_Text;

   function Integer_Text (Value : Long_Long_Integer) return String is
      Image : constant String := Long_Long_Integer'Image (Value);
   begin
      return (if Image (Image'First) = ' ' then Image (Image'First + 1 .. Image'Last) else Image);
   end Integer_Text;
end Files.Text_Basics;
