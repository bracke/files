with Files.Types;

--  The account names behind ids, memoized for the session: a listing of a
--  large folder asks for the same few owners and groups again and again.
private package Files.File_System.Account_Names is

   --  @param Id A user id.
   --  @return Its account name, or empty when the host knows none.
   function User_Name (Id : Files.Types.Account_Id) return String;

   --  @param Id A group id.
   --  @return Its group name, or empty when the host knows none.
   function Group_Name (Id : Files.Types.Account_Id) return String;

end Files.File_System.Account_Names;
