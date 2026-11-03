with Files.Types;

--  What an undo entry keeps for a permission or ownership change, and how it
--  is written into the entry's text fields (and so into the history journal).
--  One encoder and one decoder for each, used by the operation that records
--  the change, the undo and redo that apply it, and the model's check of a
--  journal entry, which had each spelled it themselves.
package Files.Undo_Payloads is

   --  An owner and group, by id, with the names they had when recorded.
   type Ownership is record
      User_Id    : Files.Types.Account_Id := 0;
      Group_Id   : Files.Types.Account_Id := 0;
      User_Name  : Files.Types.UString;
      Group_Name : Files.Types.UString;
   end record;

   --  @param Value The ownership.
   --  @return "uid gid", then the two names each after a NUL.
   function Ownership_Text (Value : Ownership) return String;

   --  Read what Ownership_Text wrote: both ids (any 32-bit value), and the
   --  names when present. Refuses a missing id, a sign, a third NUL.
   --
   --  @param Text Recorded text.
   --  @param Value The ownership read; defaults when the result is False.
   --  @return True when Text is an ownership payload.
   function Parse_Ownership (Text : String; Value : out Ownership) return Boolean;

   --  @param Mode Permission bits.
   --  @return Them as recorded.
   function Mode_Text (Mode : Natural) return String;

   --  Read what Mode_Text wrote (blanks around it allowed).
   --
   --  @param Text Recorded text.
   --  @param Mode The bits read; 0 when the result is False.
   --  @return True when Text is a mode payload.
   function Parse_Mode (Text : String; Mode : out Natural) return Boolean;

   --  @param Text Recorded text.
   --  @return Whether Parse_Mode would read it.
   function Is_Mode_Text (Text : String) return Boolean;

   --  @param Text Recorded text.
   --  @return Whether Parse_Ownership would read it.
   function Is_Ownership_Text (Text : String) return Boolean;

end Files.Undo_Payloads;
