with Ada.Real_Time;

package body Files.Operations.Undo_Recording.Testing is

   --  What Count_Undo_Records counted.
   Records : Natural := 0;

   --  The Undo_Record_Attempted hook Count_Undo_Records installs.
   procedure Note_Record is
   begin
      Records := Records + 1;
   end Note_Record;

   procedure Count_Undo_Records (Count : Boolean) is
   begin
      Records := 0;
      Undo_Record_Attempted := (if Count then Note_Record'Access else null);
   end Count_Undo_Records;

   function Undo_Records return Natural is (Records);

   --  The fake throttle clock: an instant well inside the clock's range,
   --  how often it was read, and the reading that moves it a second on.
   Fake_Epoch       : constant Ada.Real_Time.Time :=
     Ada.Real_Time.Time_Of (1_000_000, Ada.Real_Time.Time_Span_Zero);
   Fake_Readings    : Natural := 0;
   Fake_Advance_At  : Natural := 0;

   --  The Checkpoint_Clock hook Fake_Checkpoint_Clock installs.
   function Fake_Now return Ada.Real_Time.Time is
      use type Ada.Real_Time.Time;
   begin
      Fake_Readings := Fake_Readings + 1;
      if Fake_Advance_At /= 0 and then Fake_Readings >= Fake_Advance_At then
         return Fake_Epoch + Ada.Real_Time.Seconds (1);
      end if;
      return Fake_Epoch;
   end Fake_Now;

   procedure Fake_Checkpoint_Clock (Fake : Boolean; Advance_At : Natural := 0) is
   begin
      Fake_Readings := 0;
      Fake_Advance_At := Advance_At;
      Checkpoint_Clock := (if Fake then Fake_Now'Access else null);
   end Fake_Checkpoint_Clock;

   function Checkpoint_Clock_Readings return Natural is (Fake_Readings);

end Files.Operations.Undo_Recording.Testing;
