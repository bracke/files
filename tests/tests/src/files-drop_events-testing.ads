--  Test-only queries of Files.Drop_Events, kept out of the program.
package Files.Drop_Events.Testing is

   --  Return the queued path count.
   --
   --  @param Source Drop event source to inspect.
   --  @return Number of queued source paths.
   function Pending_Count (Source : Drop_Event_Source) return Natural;

end Files.Drop_Events.Testing;
