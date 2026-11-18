package body Files.History_Journal.Testing is

   procedure Refuse_Reads (Count : Natural) is
   begin
      Refused_Reads := Count;
   end Refuse_Reads;

end Files.History_Journal.Testing;
