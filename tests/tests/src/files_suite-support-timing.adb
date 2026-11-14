with Ada.Environment_Variables;

with AUnit.Assertions;

package body Files_Suite.Support.Timing is

   function Polling
     (Limit    : Duration := Poll_Limit;
      Interval : Duration := 0.001)
      return Poll_Iterators.Forward_Iterator'Class
   is
      use type Ada.Real_Time.Time;
   begin
      return Poll_Iterator'
        (Deadline => Ada.Real_Time.Clock + Ada.Real_Time.To_Time_Span (Limit),
         Interval => Interval);
   end Polling;

   overriding function Next (Object : Poll_Iterator; Position : Poll_Cursor) return Poll_Cursor is
      use type Ada.Real_Time.Time;
   begin
      delay Object.Interval;
      return (if Ada.Real_Time.Clock >= Object.Deadline then 0 else Position + 1);
   end Next;

   function Now return Instant is (Ada.Real_Time.Clock);

   function Elapsed (Since : Instant) return Span is
      use type Ada.Real_Time.Time;
   begin
      return Ada.Real_Time.Clock - Since;
   end Elapsed;

   function Seconds (Taken : Span) return Duration is (Ada.Real_Time.To_Duration (Taken));

   --  Far beyond any runner worth waiting for; it keeps Scaled clear of
   --  Duration'Last.
   Maximum_Time_Scale : constant Duration := 100.0;

   function Time_Scale return Duration is
      Text : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TIME_SCALE", "");
      Value : Duration;
   begin
      if Text = "" then
         return 1.0;
      end if;
      Value := Duration'Value (Text);
      return (if Value < 1.0 then 1.0 else Duration'Min (Value, Maximum_Time_Scale));
   exception
      when Constraint_Error =>
         return 1.0;
   end Time_Scale;

   function Scaled (Bound : Duration) return Span is
     (Ada.Real_Time.To_Time_Span (Duration (Bound * Time_Scale)));

   procedure Assert_Within (Taken : Span; Limit : Span; Message : String) is
      use type Ada.Real_Time.Time_Span;
   begin
      AUnit.Assertions.Assert
        (Taken < Limit,
         Message & " (took" & Duration'Image (Seconds (Taken)) & " s, limit"
         & Duration'Image (Seconds (Limit)) & " s)");
   end Assert_Within;

   procedure Assert_Within (Since : Instant; Limit : Span; Message : String) is
      Taken : constant Span := Elapsed (Since);
   begin
      Assert_Within (Taken, Limit, Message);
   end Assert_Within;

end Files_Suite.Support.Timing;
