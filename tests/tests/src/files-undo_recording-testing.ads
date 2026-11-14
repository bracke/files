--  Seams into undo recording for the test suite.
package Files.Undo_Recording.Testing is

   --  From now on count, from zero, each attempt Try_Record_Undo makes to
   --  record an entry (Count True); or stop counting (False).
   --
   --  @param Count Whether to count.
   procedure Count_Undo_Records (Count : Boolean);

   --  @return The attempts counted since Count_Undo_Records (True).
   function Undo_Records return Natural;

end Files.Undo_Recording.Testing;
