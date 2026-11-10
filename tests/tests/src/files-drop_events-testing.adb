package body Files.Drop_Events.Testing is

   function Pending_Count (Source : Drop_Event_Source) return Natural is
     (Natural (Source.Pending_Paths.Length));

end Files.Drop_Events.Testing;
