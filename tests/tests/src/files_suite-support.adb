with Ada.Text_IO;
with Ada.Strings;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;

package body Files_Suite.Support is

   use Ada.Strings.Unbounded;

   procedure Assert_Equal (Actual, Expected : Integer; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Actual = Expected, Message & " (expected" & Expected'Image & ", got" & Actual'Image & ")");
   end Assert_Equal;

   procedure Assert_Equal (Actual, Expected : Long_Long_Integer; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Actual = Expected, Message & " (expected" & Expected'Image & ", got" & Actual'Image & ")");
   end Assert_Equal;

   procedure Assert_Equal (Actual, Expected : String; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Actual = Expected, Message & " (expected """ & Expected & """, got """ & Actual & """)");
   end Assert_Equal;

   procedure Assert_Equal (Actual, Expected : Boolean; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Actual = Expected, Message & " (expected " & Expected'Image & ", got " & Actual'Image & ")");
   end Assert_Equal;

   procedure Assert_Inside
     (X, Y, Width, Height                         : Integer;
      Outer_X, Outer_Y, Outer_Width, Outer_Height : Integer;
      Message                                     : String) is
   begin
      AUnit.Assertions.Assert
        (X >= Outer_X, Message & " (left edge:" & X'Image & " <" & Outer_X'Image & ")");
      AUnit.Assertions.Assert
        (Y >= Outer_Y, Message & " (top edge:" & Y'Image & " <" & Outer_Y'Image & ")");
      AUnit.Assertions.Assert
        (X + Width <= Outer_X + Outer_Width,
         Message & " (right edge:" & Integer'Image (X + Width) & " >" & Integer'Image (Outer_X + Outer_Width) & ")");
      AUnit.Assertions.Assert
        (Y + Height <= Outer_Y + Outer_Height,
         Message & " (bottom edge:" & Integer'Image (Y + Height) & " >"
         & Integer'Image (Outer_Y + Outer_Height) & ")");
   end Assert_Inside;

   procedure Assert_Fits
     (X, Y, Width, Height       : Integer;
      Frame_Width, Frame_Height : Integer;
      Message                   : String) is
   begin
      AUnit.Assertions.Assert (Width > 0, Message & " (width:" & Width'Image & ")");
      AUnit.Assertions.Assert (Height > 0, Message & " (height:" & Height'Image & ")");
      AUnit.Assertions.Assert
        (X + Width <= Frame_Width,
         Message & " (right edge:" & Integer'Image (X + Width) & " >" & Frame_Width'Image & ")");
      AUnit.Assertions.Assert
        (Y + Height <= Frame_Height,
         Message & " (bottom edge:" & Integer'Image (Y + Height) & " >" & Frame_Height'Image & ")");
   end Assert_Fits;

   procedure Assert_Between (Value, Low, High : Float; Message : String) is
   begin
      AUnit.Assertions.Assert (Value >= Low, Message & " (below:" & Value'Image & " <" & Low'Image & ")");
      AUnit.Assertions.Assert (Value <= High, Message & " (above:" & Value'Image & " >" & High'Image & ")");
   end Assert_Between;

   Skipped : Natural := 0;

   Skipped_Names : Files.Types.String_Vectors.Vector;

   procedure Skip (Test : String; Reason : String) is
   begin
      Skipped := Skipped + 1;
      if not Skipped_Names.Contains (To_Unbounded_String (Test & ':' & ' ' & Reason)) then
         Skipped_Names.Append (To_Unbounded_String (Test & ':' & ' ' & Reason));
      end if;
      Ada.Text_IO.Put_Line ("SKIP" & ':' & ' ' & Test & ':' & ' ' & Reason);
   end Skip;

   function Skip_Count return Natural is (Skipped);

   function Has_Skipped (Skip : String) return Boolean is (Skipped_Names.Contains (To_Unbounded_String (Skip)));

   function Skips return Files.Types.String_Vectors.Vector is (Skipped_Names);

end Files_Suite.Support;
