--  Whole-file reads bounded by a byte cap, for the small configuration,
--  icon, settings, desktop-entry and thumbnail files the application parses.
--  Files are opened through Files.Fs, so only regular files are read and
--  nothing blocks on a FIFO or device; the bytes come back unchanged.
package Files.Capped_Files is

   --  Whether the final path component may be a symbolic link to a regular
   --  file (Follow_Links) or must itself be a regular file (Refuse_Links).
   type Link_Policy is (Refuse_Links, Follow_Links);

   --  Outcome of a capped read. Read_Too_Large means the file holds more
   --  than the cap; Read_Failed means it could not be opened or read.
   type Read_Status is (Read_Complete, Read_Too_Large, Read_Failed);

   --  Read the whole regular file at Path when it holds at most Max_Bytes
   --  bytes. The bytes are returned exactly as stored, without line-ending
   --  or encoding conversion. Never raises.
   --
   --  @param Path File to read.
   --  @param Max_Bytes Largest accepted file size in bytes; a file of
   --    exactly Max_Bytes bytes is accepted.
   --  @param Links Whether a symbolic link to a regular file is followed.
   --  @param Status Read_Complete when the whole file was read.
   --  @return The file content when Status is Read_Complete, else "".
   function Read_Capped
     (Path      : String;
      Max_Bytes : Natural;
      Links     : Link_Policy;
      Status    : out Read_Status)
      return String;

end Files.Capped_Files;
