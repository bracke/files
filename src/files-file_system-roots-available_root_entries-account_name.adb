separate (Files.File_System.Roots.Available_Root_Entries)
function Account_Name return String is
   Id : Hostkit.Metadata.Account_Id;
begin
   if Hostkit.Process.Current_User_Account (Id) then
      declare
         Name : constant String := Hostkit.Metadata.User_Name_For_Id (Id);
      begin
         if Name /= "" then
            return Name;
         end if;
      end;
   end if;
   return Hostkit.Host.Login_Name;
end Account_Name;
