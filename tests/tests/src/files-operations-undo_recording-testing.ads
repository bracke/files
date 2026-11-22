--  Seams into undo recording for the test suite.
package Files.Operations.Undo_Recording.Testing is

   --  From now on count, from zero, each attempt Try_Record_Undo makes to
   --  record an entry (Count True); or stop counting (False).
   --
   --  @param Count Whether to count.
   procedure Count_Undo_Records (Count : Boolean);

   --  @return The attempts counted since Count_Undo_Records (True).
   function Undo_Records return Natural;

   --  Make the batch Undo throttle (Checkpoint_Undo) read a fake clock, on
   --  which no second ever passes between a batch's records, except that its
   --  Advance_At'th reading (counting from one; zero for never) moves it one
   --  second on, where it stays (Fake True); or the real clock again (False).
   --
   --  @param Fake Whether to use the fake clock.
   --  @param Advance_At The reading that moves the clock one second on.
   procedure Fake_Checkpoint_Clock (Fake : Boolean; Advance_At : Natural := 0);

   --  @return How often the fake clock was read since Fake_Checkpoint_Clock.
   function Checkpoint_Clock_Readings return Natural;

end Files.Operations.Undo_Recording.Testing;
