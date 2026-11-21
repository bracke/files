--  Test seam of Files.Undo.Journal: a journal briefly unreadable.
package Files.Undo.Journal.Testing is

   --  Refuse the next Count journal reads, as a journal another process holds
   --  a moment is; 0 disarms.
   --
   --  @param Count How many reads to refuse.
   procedure Refuse_Reads (Count : Natural);

   --  @return How many of the refusals Refuse_Reads armed are still to come.
   function Refusals_Left return Natural;

end Files.Undo.Journal.Testing;
