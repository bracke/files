--  Test seam of Files.History_Journal: a journal briefly unreadable.
package Files.History_Journal.Testing is

   --  Refuse the next Count journal reads, as a journal another process holds
   --  a moment is; 0 disarms.
   --
   --  @param Count How many reads to refuse.
   procedure Refuse_Reads (Count : Natural);

end Files.History_Journal.Testing;
