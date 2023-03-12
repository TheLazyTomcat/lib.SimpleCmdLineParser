{-------------------------------------------------------------------------------

  This Source Code Form is subject to the terms of the Mozilla Public
  License, v. 2.0. If a copy of the MPL was not distributed with this
  file, You can obtain one at http://mozilla.org/MPL/2.0/.

-------------------------------------------------------------------------------}
{===============================================================================

  Simple Command Line Parser

    In current implementation, three basic objects are parsed from the command
    line - short command, long command and general object.

    Special characters

      command introduction character - dash (-)
      termination character          - semicolon (;)
      arguments delimiter character  - comma (,)
      quotation character            - double quotes (")

      WARNING - in linux, all double quotes are removed from the command line
                by the system, to ensure they are preserved for parsing,
                prepend each of them with a backslash (\)

    Short command

      - starts with a single command intro char
      - exactly one character long
      - only lower and upper case letters (a..z, A..Z)
      - case sensitive (a is NOT the same as A)
      - cannot be enclosed in quote chars
      - can be compounded (several short commands merged into one block)
      - can have arguments, first is separated by a white space, subsequent are
        delimited by a delimiter character (in counpound commands, only the
        last command can have an argument)

      Short command examples:

        -v                             simple short command
        -vbT                           compound command (commands v, b and T)
        -f file1.txt, "file 2.txt"     simple with two arguments
        -Tzf "file.dat"                compound, last command (f) with one argument

    Long command

      - starts with two command intro chars
      - length is not explicitly limited
      - only lower and upper case letters (a..z, A..Z), numbers (0..9),
        underscore (_) and dash (-)
      - case insensitive (FOO is the same as Foo)
      - cannot start with a dash
      - cannot contain white-space characters
      - cannot be enclosed in quote chars
      - cannot be compounded
      - can have arguments, first argument is separated by a white space,
        subsequent are delimited by a delimiter character

      Long command examples:

        --show_warnings                       simple long command
        --input_file "file1.txt"              simple with one argument
        --files "file1.dat", "files2.dat"     simple with two arguments

    General object

      - any text that is not a command, delimiter, dash or termination char
      - cannot contain whitespaces, delimiter, quotation or command intro
        character...
      - ...unless it is enclosed in quote chars
      - to add one quote char, escape it with another one
      - if general object has to appear after a command (normally, it would be
        parsed as a command argument), add command termination character after
        the command and before the text
      - if first parsed object from a command line is a general object, it is
        assumed to be the image path

      General object examples:

        this_is_simple_general_text
        "quoted text with ""whitespaces"" and quote chars"
        "special characters: - -- , """   

  Version 1.2.1 (2020-07-27)

  Last change 2022-09-24

  ©2017-2022 František Milt

  Contacts:
    František Milt: frantisek.milt@gmail.com

  Support:
    If you find this code useful, please consider supporting its author(s) by
    making a small donation using the following link(s):

      https://www.paypal.me/FMilt

  Changelog:
    For detailed changelog and history please refer to this git repository:

      github.com/TheLazyTomcat/Lib.SimpleCmdLineParser

  Dependencies:
    AuxTypes           - github.com/TheLazyTomcat/Lib.AuxTypes
    AuxClasses         - github.com/TheLazyTomcat/Lib.AuxClasses
  * StrRect            - github.com/TheLazyTomcat/Lib.StrRect

    Library StrRect is required only when compiling for Windows OS.

===============================================================================}
unit SimpleCmdLineParser;

{$IF Defined(WINDOWS) or Defined(MSWINDOWS)}
  {$DEFINE Windows}
{$ELSEIF Defined(LINUX) and Defined(FPC)}
  {$DEFINE Linux}
{$ELSE}
  {$MESSAGE FATAL 'Unsupported operating system.'}
{$IFEND}

{$IFDEF FPC}
  {$MODE ObjFPC}
  {$MODESWITCH DuplicateLocals+}
  {$DEFINE FPC_DisableWarns}
  {$MACRO ON}
{$ENDIF}
{$H+}

interface

uses
  SysUtils,
  AuxClasses;

{===============================================================================
    Library-specific exceptions
===============================================================================}
type
  ESCLPException = class(Exception);

  ESCLPIndexOutOfBounds = class(ESCLPException);
  ESCLPInvalidValue     = class(ESCLPException);
  ESCLPInvalidState     = class(ESCLPException);

{===============================================================================
--------------------------------------------------------------------------------
                                  TSCLPParser                                  
--------------------------------------------------------------------------------
===============================================================================}
type
  // note that ptCommandBoth is only used when returning command data
  TSCLPParamType = (ptGeneral,ptCommandShort,ptCommandLong,ptCommandBoth);

  TSCLPParameter = record
    ParamType:  TSCLPParamType;
    Str:        String;
    Arguments:  array of String;
  end;

{===============================================================================
    TSCLPParser - class declaration
===============================================================================}
type
  TSCLPParser = class(TCustomListObject)
  protected
    // data
    fCommandLine:   String;
    fImagePath:     String;
    fParameters:    array of TSCLPParameter;
    fCount:         Integer;
    fCommandCount:  Integer;
    fLexer:         TObject;
    Function GetParameter(Index: Integer): TSCLPParameter; virtual;
    // list methods
    Function GetCapacity: Integer; override;
    procedure SetCapacity(Value: Integer); override;
    Function GetCount: Integer; override;
    procedure SetCount(Value: Integer); override;
    // parameter list manipulation
    Function AddParam(ParamType: TSCLPParamType; const Str: String): Integer; virtual;
    class procedure AddParamArgument(var Param: TSCLPParameter; const Arg: String); overload; virtual;
    procedure AddParamArgument(Index: Integer; const Arg: String); overload; virtual;
    // init/final
    procedure Initialize; virtual;
    procedure Finalize; virtual;
  public
    class Function GetCommandLine: String; virtual;
    constructor CreateEmpty;
    constructor Create(const CommandLine: String); overload;
    // following parses command line of the current program
    constructor Create{$IFNDEF FPC}(Dummy: Integer = 0){$ENDIF}; overload;
    destructor Destroy; override;
    Function LowIndex: Integer; override;
    Function HighIndex: Integer; override;
    Function First: TSCLPParameter; virtual;
    Function Last: TSCLPParameter; virtual;
    Function IndexOf(const Str: String; CaseSensitive: Boolean): Integer; virtual;
  {
    CommandPresentShort

    Returns true when given short command is present at least once, false
    otherwise.
  }
    Function CommandPresentShort(ShortForm: Char): Boolean; virtual;
  {
    CommandPresentLong

    Returns true when given long command is present at least once, false
    otherwise.
  }
    Function CommandPresentLong(const LongForm: String): Boolean; virtual;
  {
    CommandPresent

    Returns true when either short or long form of selected command is present
    at least once, false otherwise.
  }
    Function CommandPresent(ShortForm: Char; const LongForm: String): Boolean; virtual;
  {
    CommandDataShort

    Returns true when selected short form command is present, false otherwise.

    When successfull, CommandData is set to selected short form string and
    type is set to short command. It will also contain arguments from all
    occurences of selected command, in the order they appear in the command
    line.
    When not successfull, content of CommandData is undefined.
  }
    Function CommandDataShort(ShortForm: Char; out CommandData: TSCLPParameter): Boolean; virtual;
  {
    CommandDataLong

    Returns true when selected long form command is present, false otherwise.

    When successfull, CommandData is set to selected long form string and
    type is set to long command. It will also contain arguments from all
    occurences of selected command, in the order they appear in the command
    line.
    When not successfull, content of CommandData is undefined.
  }
    Function CommandDataLong(const LongForm: String; out CommandData: TSCLPParameter): Boolean; virtual;
  {
    CommandData

    Returns true when either long form or short form of selected command is
    present, false otherwise.

    When successfull, CommandData will also contain arguments from all
    occurences of selected command, in the order they appear in the command
    line. Type and string is set to short form when only short form is present,
    to long form when only long form is present. When both forms are present,
    then the string is set to a long form and type is set to ptCommandBoth.
    When not successfull, content of CommandData is undefined.
  }
    Function CommandData(ShortForm: Char; const LongForm: String; out CommandData: TSCLPParameter): Boolean; virtual;
    procedure Clear; virtual;
    procedure Parse(const CommandLine: String); overload; virtual;
    // following parses command line of the current program
    procedure Parse; overload; virtual;
    property CommandLine: String read fCommandLine;
    property ImagePath: String read fImagePath;
    property Parameters[Index: Integer]: TSCLPParameter read GetParameter; default;
  {
    CommandCount

    Returns number of commands (both long and short) in parameter list, as
    opposed to property Count, which indicates number of all parameters.

    DO NOT use this number to iterate trough Parameters.
  }
    property CommandCount: Integer read fCommandCount;
  end;

implementation


uses
  {$IFDEF Windows}Windows,{$ELSE}Math,{$ENDIF}
  AuxTypes{$IFDEF Windows}, StrRect{$ENDIF};

{$IFDEF FPC_DisableWarns}
  {$DEFINE FPCDWM}
  {$DEFINE W5024:={$WARN 5024 OFF}} // Parameter "$1" not used
{$ENDIF}
  
{===============================================================================
    Auxiliary functions
===============================================================================}

{$If not Declared(CharInSet)}

Function CharInSet(C: AnsiChar; const CharSet: TSysCharSet): Boolean; overload;
begin
Result := C in CharSet;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

Function CharInSet(C: WideChar; const CharSet: TSysCharSet): Boolean; overload;
begin
If Ord(C) <= 255 then
  Result := AnsiChar(C) in CharSet
else
  Result := False;
end;

{$IFEND}

{===============================================================================
--------------------------------------------------------------------------------
                                   TSCLPLexer
--------------------------------------------------------------------------------
===============================================================================}
type
  TSCLPLexerTokenType = (lttGeneral,lttCommandShort,lttCommandLong);

  TSCLPLexerToken = record
    TokenType:    TSCLPLexerTokenType;
    OriginalStr:  String;   // unprocessed string, as it appears in the command line
    Position:     Integer;  // position of the token in command line string
    Str:          String;   // processed text of the token
  end;

  TSCLPLexerCharType = (lctWhiteSpace,lctCommandIntro,lctQuoteSingle,
                        lctQuoteDouble,lctEscape,lctOther);

  TSCLPLexerState = (lsStart,lsWhiteSpace,lsCommandIntro,lsCommandIntroDouble,
                     lsCommandShort,lsCommandLong,lsQuotedSingle,lsQuotedDouble,
                     lsEscape,lsEscapeQuotedSingle,lsEscapeQuotedDouble,lsText);

const
  SCLP_CHAR_CMDINTRO    = '-';
  SCLP_CHAR_QUOTESINGLE = '''';
  SCLP_CHAR_QUOTEDOUBLE = '"';
  SCLP_CHAR_ESCAPE      = '\';

  SCLP_CHARS_WHITESPACE   = [#0..#32];
  SCLP_CHARS_COMMANDSHORT = ['a'..'z','A'..'Z'];
  SCLP_CHARS_COMMANDLONG  = ['a'..'z','A'..'Z','0'..'9','_','-'];

{===============================================================================
    TSCLPLexer - class declaration
===============================================================================}
type
  TSCLPLexer = class(TCustomListObject)
  protected
    // data
    fCommandLine: String;
    fTokens:      array of TSCLPLexerToken;
    fCount:       Integer;
    // lexing variables
    fState:       TSCLPLexerState;
    fPosition:    TStrOff;
    fTokenStart:  TStrOff;
    fTokenLength: TStrSize;
    // getters, setters
    Function GetToken(Index: Integer): TSCLPLexerToken; virtual;
    // inherited list methods
    Function GetCapacity: Integer; override;
    procedure SetCapacity(Value: Integer); override;
    Function GetCount: Integer; override;
    procedure SetCount(Value: Integer); override;
    // lexing
    Function CurrCharType: TSCLPLexerCharType; virtual;
    procedure ChangeStateAndAdvance(NewState: TSCLPLexerState); virtual;
    procedure AddToken(TokenType: TSCLPLexerTokenType); virtual;
    procedure Process_Start; virtual;
    procedure Process_WhiteSpace; virtual;
    procedure Process_CommandIntro; virtual;
    procedure Process_CommandIntroDouble; virtual;
    procedure Process_CommandShort; virtual;
    procedure Process_CommandLong; virtual;
    procedure Process_QuotedSingle; virtual;
    procedure Process_QuotedDouble; virtual;
    procedure Process_Escape; virtual;
    procedure Process_EscapeQuotedSingle; virtual;
    procedure Process_EscapeQuotedDouble; virtual;
    procedure Process_Text; virtual;
    // init/final
    procedure Initialize; virtual;
    procedure Finalize; virtual;
  public
    constructor Create;
    destructor Destroy; override;
    Function LowIndex: Integer; override;
    Function HighIndex: Integer; override;
    procedure Analyze(const CommandLine: String); virtual;
    procedure Clear; virtual;
    property Tokens[Index: Integer]: TSCLPLexerToken read GetToken; default;
    property CommandLine: String read fCommandLine;
  end;

  
{===============================================================================
    TSCLPLexer - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TSCLPLexer - protected methods
-------------------------------------------------------------------------------}

Function TSCLPLexer.GetToken(Index: Integer): TSCLPLexerToken;
begin
If CheckIndex(Index) then
  Result := fTokens[Index]
else
  raise ESCLPIndexOutOfBounds.CreateFmt('TSCLPLexer.GetToken: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TSCLPLexer.GetCapacity: Integer;
begin
Result := Length(fTokens);
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.SetCapacity(Value: Integer);
begin
If Value >= 0 then
  begin
    If Value <> Length(fTokens) then
      begin
        SetLength(fTokens,Value);
        If Value < fCount then
          fCount := Value
      end;
  end
else raise ESCLPInvalidValue.CreateFmt('TSCLPLexer.SetCapacity: Invalid capacity (%d).',[Value]);
end;

//------------------------------------------------------------------------------

Function TSCLPLexer.GetCount: Integer;
begin
Result := fCount;
end;

//------------------------------------------------------------------------------

{$IFDEF FPCDWM}{$PUSH}W5024{$ENDIF}
procedure TSCLPLexer.SetCount(Value: Integer);
begin
// do nothing
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//------------------------------------------------------------------------------

Function TSCLPLexer.CurrCharType: TSCLPLexerCharType;
begin
If CharInSet(fCommandLine[fPosition],SCLP_CHARS_WHITESPACE) then
  Result := lctWhiteSpace
else If fCommandLine[fPosition] = SCLP_CHAR_CMDINTRO then
  Result := lctCommandIntro
else If fCommandLine[fPosition] = SCLP_CHAR_QUOTESINGLE then
  Result := lctQuoteSingle
else If fCommandLine[fPosition] = SCLP_CHAR_QUOTEDOUBLE then
  Result := lctQuoteDouble
else If fCommandLine[fPosition] = SCLP_CHAR_ESCAPE then
  Result := lctEscape
else
  Result := lctOther;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.ChangeStateAndAdvance(NewState: TSCLPLexerState);
begin
fState := NewState;
Inc(fTokenLength);
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.AddToken(TokenType: TSCLPLexerTokenType);

  Function PostprocessTokenString(const Str: String): String;
  type
    TQuoteState = (qsNone,qsSingle,qsDouble,qsEscape,qsEscapeSingle,qsEscapeDouble);
  var
    QuoteState: TQuoteState;
    StrPos:     TStrOff;
    ResPos:     TStrOff;

    procedure CopyChar(NewQuoteState: TQuoteState);
    begin
      QuoteState := NewQuoteState;
      Result[ResPos] := Str[StrPos];
      Inc(StrPos);
      Inc(ResPos);
    end;

    procedure ChageState(NewQuoteState: TQuoteState);
    begin
      QuoteState := NewQuoteState;
      Inc(StrPos);
    end;

  begin
    // note the resulting string will never be longer than the original
    SetLength(Result,Length(Str));
    QuoteState := qsNone;
    StrPos := 1;
    ResPos := 1;
    while StrPos <= Length(Str) do
      begin
        case QuoteState of
          qsNone:         case Str[StrPos] of
                            SCLP_CHAR_QUOTESINGLE:  ChageState(qsSingle);
                            SCLP_CHAR_QUOTEDOUBLE:  ChageState(qsDouble);
                            SCLP_CHAR_ESCAPE:       ChageState(qsEscape);
                          else
                            CopyChar(qsNone);
                          end;
          qsSingle:       case Str[StrPos] of
                            SCLP_CHAR_QUOTESINGLE:  ChageState(qsNone);
                            SCLP_CHAR_ESCAPE:       ChageState(qsEscapeSingle);
                          else
                            CopyChar(qsSingle);
                          end;
          qsDouble:       case Str[StrPos] of
                            SCLP_CHAR_QUOTEDOUBLE:  ChageState(qsNone);
                            SCLP_CHAR_ESCAPE:       ChageState(qsEscapeDouble);
                          else
                            CopyChar(qsDouble);
                          end;
          qsEscape:       CopyChar(qsNone);
          qsEscapeSingle: CopyChar(qsSingle);
          qsEscapeDouble: CopyChar(qsDouble);
        end;
      end;
    If QuoteState in [qsEscape,qsEscapeSingle,qsEscapeDouble] then
      begin
        Result[ResPos] := SCLP_CHAR_ESCAPE;
        SetLength(Result,ResPos);
      end
    else SetLength(Result,Pred(ResPos));
  end;

var
  i:  Integer;
begin
If (TokenType = lttCommandShort) and (fTokenLength > 2) then
  begin
    // split compound short commands (eg. -abc -> -a -b -c)
    Grow(Pred(fTokenLength));
    For i := 0 to (fTokenLength - 2) do
      begin
        fTokens[fCount + i].TokenType := lttCommandShort;
        If i <= 0 then
          begin
            fTokens[fCount + i].OriginalStr := Copy(fCommandLine,fTokenStart,2);
            fTokens[fCount + i].Str :=  fCommandLine[fTokenStart + i + 1];
          end
        else
          begin
            fTokens[fCount + i].OriginalStr := fCommandLine[fTokenStart + i + 1];
            fTokens[fCount + i].Str := fTokens[fCount + i].OriginalStr
          end;
        fTokens[fCount + i].Position := fTokenStart + i + 1;
      end;
    Inc(fCount,Pred(fTokenLength));
  end
else
  begin
    Grow;
    fTokens[fCount].TokenType := TokenType;
    fTokens[fCount].OriginalStr := Copy(fCommandLine,fTokenStart,fTokenLength);
    fTokens[fCount].Position := fTokenStart;
    case TokenType of
      lttGeneral:       fTokens[fCount].Str := PostprocessTokenString(fTokens[fCount].OriginalStr);
      lttCommandShort:  fTokens[fCount].Str := fCommandLine[fTokenStart + 1];
      lttCommandLong:   fTokens[fCount].Str := Copy(fCommandLine,fTokenStart + 2,fTokenLength - 2);
    end;
    Inc(fCount);
  end;
fTokenLength := 0;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_Start;
begin
fState := lsWhiteSpace;
fPosition := 0;
fTokenStart := 0;
fTokenLength := 0;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_WhiteSpace;
begin
case CurrCharType of
  lctWhiteSpace:;   // just continue
  lctCommandIntro:  begin
                      fState := lsCommandIntro;
                      fTokenStart := fPosition;
                      fTokenLength := 1;
                    end;
  lctQuoteSingle:   begin
                      fState := lsQuotedSingle;
                      fTokenStart := fPosition;
                      fTokenLength := 1;
                    end;
  lctQuoteDouble:   begin
                      fState := lsQuotedDouble;
                      fTokenStart := fPosition;
                      fTokenLength := 1;
                    end;
  lctEscape:        begin
                      fState := lsEscape;
                      fTokenStart := fPosition;
                      fTokenLength := 1;
                    end;
  lctOther:         begin
                      fState := lsText;
                      fTokenStart := fPosition;
                      fTokenLength := 1;
                    end;
end;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_CommandIntro;
begin
case CurrCharType of
  lctWhiteSpace:    begin
                      AddToken(lttGeneral);
                      fState := lsWhiteSpace;
                    end;
  lctCommandIntro:  ChangeStateAndAdvance(lsCommandIntroDouble);
  lctQuoteSingle:   ChangeStateAndAdvance(lsQuotedSingle);
  lctQuoteDouble:   ChangeStateAndAdvance(lsQuotedDouble);
  lctEscape:        ChangeStateAndAdvance(lsEscape);
  lctOther:         begin
                      If CharInSet(fCommandLine[fPosition],SCLP_CHARS_COMMANDSHORT) then
                        fState := lsCommandShort
                      else
                        fState := lsText;
                      Inc(fTokenLength);
                    end;
end;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_CommandIntroDouble;
begin
case CurrCharType of
  lctWhiteSpace:    begin
                      AddToken(lttGeneral);
                      fState := lsWhiteSpace;
                    end;
  lctCommandIntro:  ChangeStateAndAdvance(lsText);
  lctQuoteSingle:   ChangeStateAndAdvance(lsQuotedSingle);
  lctQuoteDouble:   ChangeStateAndAdvance(lsQuotedDouble);
  lctEscape:        ChangeStateAndAdvance(lsEscape);
  lctOther:         begin
                      If CharInSet(fCommandLine[fPosition],SCLP_CHARS_COMMANDLONG) then
                        fState := lsCommandLong
                      else
                        fState := lsText;
                      Inc(fTokenLength);
                    end;
end;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_CommandShort;
begin
case CurrCharType of
  lctWhiteSpace:    begin
                      AddToken(lttCommandShort);
                      fState := lsWhiteSpace;
                    end;
  lctCommandIntro:  ChangeStateAndAdvance(lsText);
  lctQuoteSingle:   ChangeStateAndAdvance(lsQuotedSingle);
  lctQuoteDouble:   ChangeStateAndAdvance(lsQuotedDouble);
  lctEscape:        ChangeStateAndAdvance(lsEscape);

  lctOther:         begin
                      If not CharInSet(fCommandLine[fPosition],SCLP_CHARS_COMMANDSHORT) then
                        fState := lsText;
                      Inc(fTokenLength);
                    end;
end;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_CommandLong;
begin
case CurrCharType of
  lctWhiteSpace:    begin
                      AddToken(lttCommandLong);
                      fState := lsWhiteSpace;
                    end;
  lctQuoteSingle:   ChangeStateAndAdvance(lsQuotedSingle);
  lctQuoteDouble:   ChangeStateAndAdvance(lsQuotedDouble);
  lctEscape:        ChangeStateAndAdvance(lsEscape);
  lctCommandIntro,
  lctOther:         begin
                      If not CharInSet(fCommandLine[fPosition],SCLP_CHARS_COMMANDLONG) then
                        fState := lsText;
                      Inc(fTokenLength);
                    end;
end;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_QuotedSingle;
begin
case CurrCharType of
  lctQuoteSingle: ChangeStateAndAdvance(lsText);
  lctEscape:      ChangeStateAndAdvance(lsEscapeQuotedSingle);
else
 {lctWhiteSpace,lctCommandIntro,lctQuoteDouble,lctOther}
  Inc(fTokenLength);
end;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_QuotedDouble;
begin
case CurrCharType of
  lctQuoteDouble: ChangeStateAndAdvance(lsText);
  lctEscape:      ChangeStateAndAdvance(lsEscapeQuotedDouble);
else
 {lctWhiteSpace,lctCommandIntro,lctQuoteSingle,lctOther}
  Inc(fTokenLength);
end;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_Escape;
begin
ChangeStateAndAdvance(lsText);
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_EscapeQuotedSingle;
begin
ChangeStateAndAdvance(lsQuotedSingle);
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_EscapeQuotedDouble;
begin
ChangeStateAndAdvance(lsQuotedDouble);
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Process_Text;
begin
case CurrCharType of
  lctWhiteSpace:    begin
                      AddToken(lttGeneral);
                      fState := lsWhiteSpace;
                    end;
  lctQuoteSingle:   ChangeStateAndAdvance(lsQuotedSingle);
  lctQuoteDouble:   ChangeStateAndAdvance(lsQuotedDouble);
  lctEscape:        ChangeStateAndAdvance(lsEscape)
else
 {lctCommandIntro,lctOther}
  Inc(fTokenLength);
end;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Initialize;
begin
fCommandLine := '';
SetLength(fTokens,0);
fCount := 0;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Finalize;
begin
Clear;
end;

{-------------------------------------------------------------------------------
    TSCLPLexer - public methods
-------------------------------------------------------------------------------}

constructor TSCLPLexer.Create;
begin
inherited;
Initialize;
end;

//------------------------------------------------------------------------------

destructor TSCLPLexer.Destroy;
begin
Finalize;
inherited;
end;

//------------------------------------------------------------------------------

Function TSCLPLexer.LowIndex: Integer;
begin
Result := Low(fTokens);
end;

//------------------------------------------------------------------------------

Function TSCLPLexer.HighIndex: Integer;
begin
Result := Pred(fCount);
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Analyze(const CommandLine: String);
begin
Clear;
fCommandLine := CommandLine;
fState := lsStart;
fPosition := 0;
while fPosition <= Length(fCommandLine) do
  begin
    case fState of
      lsStart:              Process_Start;
      lsWhiteSpace:         Process_WhiteSpace;
      lsCommandIntro:       Process_CommandIntro;
      lsCommandIntroDouble: Process_CommandIntroDouble;
      lsCommandShort:       Process_CommandShort;
      lsCommandLong:        Process_CommandLong;
      lsQuotedSingle:       Process_QuotedSingle;
      lsQuotedDouble:       Process_QuotedDouble;
      lsEscape:             Process_Escape;
      lsEscapeQuotedSingle: Process_EscapeQuotedSingle;
      lsEscapeQuotedDouble: Process_EscapeQuotedDouble;
      lsText:               Process_Text;
    else
      raise ESCLPInvalidState.CreateFmt('TSCLPLexer.Analyze: Invalid lexer state (%d).',[Ord(fState)]);
    end;
    Inc(fPosition);
  end;
case fState of
  lsCommandShort:       AddToken(lttCommandShort);
  lsCommandLong:        AddToken(lttCommandLong);
  lsCommandIntro,
  lsCommandIntroDouble,
  lsQuotedSingle,
  lsQuotedDouble,
  lsEscape,
  lsEscapeQuotedSingle,
  lsEscapeQuotedDouble,
  lsText:               AddToken(lttGeneral);
end;
end;

//------------------------------------------------------------------------------

procedure TSCLPLexer.Clear;
begin
fCommandLine := '';
SetLength(fTokens,0);
fCount := 0;
end;


{===============================================================================
--------------------------------------------------------------------------------
                                  TSCLPParser                                  
--------------------------------------------------------------------------------
===============================================================================}
{===============================================================================
    TSCLPParser - class implementation
===============================================================================}
{-------------------------------------------------------------------------------
    TSCLPParser - protected methods
-------------------------------------------------------------------------------}

Function TSCLPParser.GetParameter(Index: Integer): TSCLPParameter;
begin
If CheckIndex(Index) then
  Result := fParameters[Index]
else
  raise ESCLPIndexOutOfBounds.CreateFmt('TSCLPParser.GetParameter: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

Function TSCLPParser.GetCapacity: Integer;
begin
Result := Length(fParameters);
end;

//------------------------------------------------------------------------------

procedure TSCLPParser.SetCapacity(Value: Integer);
begin
If Value >= 0 then
  begin
    If Value <> Length(fParameters) then
      begin
        SetLength(fParameters,Value);
        If Value < fCount then
          fCount := Value;
      end;
  end
else raise ESCLPInvalidValue.CreateFmt('TSCLPParser.SetCapacity: Invalid capacity (%d).',[Value]);
end;

//------------------------------------------------------------------------------

Function TSCLPParser.GetCount: Integer;
begin
Result := fCount;
end;

//------------------------------------------------------------------------------

{$IFDEF FPCDWM}{$PUSH}W5024{$ENDIF}
procedure TSCLPParser.SetCount(Value: Integer);
begin
// do nothing
end;
{$IFDEF FPCDWM}{$POP}{$ENDIF}

//------------------------------------------------------------------------------

Function TSCLPParser.AddParam(ParamType: TSCLPParamType; const Str: String): Integer;
begin
Grow;
Result := fCount;
fParameters[Result].ParamType := ParamType;
fParameters[Result].Str := Str;
SetLength(fParameters[Result].Arguments,0);
Inc(fCount);
If ParamType in [ptCommandShort,ptCommandLong] then
  Inc(fCommandCount);
end;

//------------------------------------------------------------------------------

class procedure TSCLPParser.AddParamArgument(var Param: TSCLPParameter; const Arg: String);
begin
SetLength(Param.Arguments,Length(Param.Arguments) + 1);
Param.Arguments[High(Param.Arguments)] := Arg;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TSCLPParser.AddParamArgument(Index: Integer; const Arg: String);
begin
If CheckIndex(Index) then
  AddParamArgument(fParameters[Index],Arg)
else
  raise ESCLPIndexOutOfBounds.CreateFmt('TSCLPParser.AddParamArgument: Index (%d) out of bounds.',[Index]);
end;

//------------------------------------------------------------------------------

procedure TSCLPParser.Initialize;
begin
fCommandLine := '';
fImagePath := '';
SetLength(fParameters,0);
fCommandCount := 0;
fCount := 0;
fLexer := TSCLPLexer.Create;
end;

//------------------------------------------------------------------------------

procedure TSCLPParser.Finalize;
begin
Clear;
fLexer.Free;
end;

{-------------------------------------------------------------------------------
    TSCLPParser - public methods
-------------------------------------------------------------------------------}

class Function TSCLPParser.GetCommandLine: String;
{$IFDEF Windows}

  Function PreprocessCommandLine(const CmdLine: String): String;
  var
    i:      TStrOff;
    Cntr:   TStrSize;
    ResPos: TStrOff;
  begin
    // double all escape characters (backslash)
    Cntr := 0;
    For i := 1 to Length(CmdLine) do
      If CmdLine[i] = SCLP_CHAR_ESCAPE then
        Inc(Cntr);
    SetLength(Result,Length(CmdLine) + Cntr);
    ResPos := 1;
    For i := 1 to Length(CmdLine) do
      begin
        If CmdLine[i] = SCLP_CHAR_ESCAPE then
          begin
            Result[ResPos] := SCLP_CHAR_ESCAPE;
            Inc(ResPos);
          end;
        Result[ResPos] := CmdLine[i];
        Inc(ResPos);
      end;
  end;

var
  CmdLine:  PChar;
begin
CmdLine := Windows.GetCommandLine;
If Assigned(CmdLine) then
  Result := PreprocessCommandLine(WinToStr(CmdLine))
else
  Result := '';
end;
{$ELSE}

  Function PreprocessArgument(const Arg: String): String;
  var
    i,ResPos:   TStrOff;
    CanBeSCmd:  Boolean;
    CanBeLCmd:  Boolean;
    AddQuote:   Boolean;
    EscapeCnt:  Integer;
  begin
    {$message 'rework'}
    If Length(Arg) > 0 then
      begin
        CanBeSCmd := Arg[1] = SCLP_CHAR_CMDINTRO;
        If Length(Arg) > 1 then
          CanBeLCmd := Arg[2] = SCLP_CHAR_CMDINTRO
        else
          CanBeLCmd := False;
        AddQuote := False;
        EscapeCnt := 0;
        // scan the argument string
        For i := 1 to Length(Arg) do
          begin
            If CharInSet(Arg[i],SCLP_CHARS_WHITESPACE) then
              begin
                CanBeSCmd := False;
                CanBeLCmd := False;
                AddQuote := True;
              end
            else If not CharInSet(Arg[i],SCLP_CHARS_SHORTCOMMAND) then
              begin
                CanBeSCmd := False;
                CanBeLCmd := CharInSet(Arg[i],SCLP_CHARS_LONGCOMMAND);
              end
            else If Arg[i] = SCLP_CHAR_QUOTEDOUBLE then
              Inc(EscapeCnt);
          end;
      {
        If the string starts with command intro char, but cannot be a command,
        then prepend it with an escape char.
      }
        If (Arg[1] = SCLP_CHAR_CMDINTRO) and not(CanBeSCmd or CanBeLCmd) then
          Inc(EscapeCnt);
        // build the resulting string
        SetLength(Result,Length(Arg) + EscapeCnt + IfThen(AddQuote,2,0));
        If AddQuote then
          begin
            Result[1] := SCLP_CHAR_QUOTEDOUBLE;
            Result[Length(Result)] := SCLP_CHAR_QUOTEDOUBLE;
            ResPos := 2;
          end
        else ResPos := 1;
        If (Arg[1] = SCLP_CHAR_CMDINTRO) and not(CanBeSCmd or CanBeLCmd) then
          begin
            Result[ResPos] := SCLP_CHAR_ESCAPE;
            Inc(ResPos);
          end;
        For i := 1 to Length(Arg) do
          begin
            If Arg[i] = SCLP_CHAR_QUOTEDOUBLE then
              begin
                Result[ResPos] := SCLP_CHAR_ESCAPE;
                Inc(ResPos);
              end;
            Result[ResPos] := Arg[i];
            Inc(ResPos);
          end;
      end
    else Result := StringOfChar(SCLP_CHAR_QUOTEDOUBLE,2);
  end;

var
  Arguments:  PPointer;
  i:          Integer;
begin
// reconstruct command line
If (argc > 0) and Assigned(argv) then
  begin
    Arguments := PPointer(argv);
    Result := '';
    For i := 1 to argc do
      If Assigned(Arguments^) then
        begin
          If Length(Result) > 0 then
            Result := Result + ' ' + PreprocessArgument(PPChar(Arguments)^)
          else
            Result := PreprocessArgument(PPChar(Arguments)^);
          Inc(Arguments);
        end
      else Break{For i};
  end
else Result := '';
end;
{$ENDIF}

//------------------------------------------------------------------------------

constructor TSCLPParser.CreateEmpty;
begin
inherited;
Initialize;
end;

//------------------------------------------------------------------------------

constructor TSCLPParser.Create(const CommandLine: String);
begin
CreateEmpty;
Parse(CommandLine);
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

constructor TSCLPParser.Create{$IFNDEF FPC}(Dummy: Integer = 0){$ENDIF};
begin
Create(GetCommandLine);
end;

//------------------------------------------------------------------------------

destructor TSCLPParser.Destroy;
begin
Finalize;
inherited;
end;

//------------------------------------------------------------------------------

Function TSCLPParser.LowIndex: Integer;
begin
Result := Low(fParameters);
end;

//------------------------------------------------------------------------------

Function TSCLPParser.HighIndex: Integer;
begin
Result := Pred(fCount);
end;

//------------------------------------------------------------------------------

Function TSCLPParser.First: TSCLPParameter;
begin
Result := GetParameter(LowIndex);
end;

//------------------------------------------------------------------------------

Function TSCLPParser.Last: TSCLPParameter;
begin
Result := GetParameter(HighIndex);
end;

//------------------------------------------------------------------------------

Function TSCLPParser.IndexOf(const Str: String; CaseSensitive: Boolean): Integer;
var
  i:  Integer;
begin
Result := -1;
{
  There are two seperate cycles for performance reasons - it removes check for
  CaseSensitive that would be otherwise in every single iteration.
}
If CaseSensitive then
  begin
    For i := LowIndex to HighIndex do
      If AnsiSameStr(Str,fParameters[i].Str) then
        begin
          Result := i;
          Break{For i};
        end;
  end
else
  begin
    For i := LowIndex to HighIndex do
      If AnsiSameText(Str,fParameters[i].Str) then
        begin
          Result := i;
          Break{For i};
        end;
  end;
end;

//------------------------------------------------------------------------------

Function TSCLPParser.CommandPresentShort(ShortForm: Char): Boolean;
var
  Index:  Integer;
begin
Index := IndexOf(ShortForm,True);
If CheckIndex(Index) then
  Result := fParameters[Index].ParamType = ptCommandShort
else
  Result := False;
end;

//------------------------------------------------------------------------------

Function TSCLPParser.CommandPresentLong(const LongForm: String): Boolean;
var
  Index:  Integer;
begin
Index := IndexOf(LongForm,False);
If CheckIndex(Index) then
  Result := fParameters[Index].ParamType = ptCommandLong
else
  Result := False;
end;

//------------------------------------------------------------------------------

Function TSCLPParser.CommandPresent(ShortForm: Char; const LongForm: String): Boolean;
begin
Result := CommandPresentShort(ShortForm) or CommandPresentLong(LongForm);
end;

//------------------------------------------------------------------------------

Function TSCLPParser.CommandDataShort(ShortForm: Char; out CommandData: TSCLPParameter): Boolean;
var
  i,j:  Integer;
begin
Result := False;
CommandData.ParamType := ptCommandShort;
CommandData.Str := ShortForm;
SetLength(CommandData.Arguments,0);
For i := LowIndex to HighIndex do
  If (fParameters[i].ParamType = ptCommandShort) and
     AnsiSameStr(ShortForm,fParameters[i].Str) then
    begin
      For j := Low(fParameters[i].Arguments) to High(fParameters[i].Arguments) do
        AddParamArgument(CommandData,fParameters[i].Arguments[j]);
      Result := True;
    end;
end;

//------------------------------------------------------------------------------

Function TSCLPParser.CommandDataLong(const LongForm: String; out CommandData: TSCLPParameter): Boolean;
var
  i,j:  Integer;
begin
Result := False;
CommandData.ParamType := ptCommandLong;
CommandData.Str := LongForm;
SetLength(CommandData.Arguments,0);
For i := LowIndex to HighIndex do
  If (fParameters[i].ParamType = ptCommandLong) and
     AnsiSameText(LongForm,fParameters[i].Str) then
    begin
      For j := Low(fParameters[i].Arguments) to High(fParameters[i].Arguments) do
        AddParamArgument(CommandData,fParameters[i].Arguments[j]);
      Result := True;
    end;
end;

//------------------------------------------------------------------------------

Function TSCLPParser.CommandData(ShortForm: Char; const LongForm: String; out CommandData: TSCLPParameter): Boolean;
var
  i,j:  Integer;
begin
Result := False;
CommandData.ParamType := ptGeneral;
SetLength(CommandData.Arguments,0);
For i := LowIndex to HighIndex do
  If (fParameters[i].ParamType = ptCommandShort) and AnsiSameStr(ShortForm,fParameters[i].Str) then
    begin
      case CommandData.ParamType of
        ptGeneral:      begin
                          CommandData.ParamType := ptCommandShort;
                          CommandData.Str := ShortForm;
                        end;
        ptCommandLong:  CommandData.ParamType := ptCommandBoth;
      else
       {ptCommandShort,ptCommandBoth - do nothing}
      end;
      For j := Low(fParameters[i].Arguments) to High(fParameters[i].Arguments) do
        AddParamArgument(CommandData,fParameters[i].Arguments[j]);
      Result := True;
    end
  else If (fParameters[i].ParamType = ptCommandLong) and AnsiSameText(LongForm,fParameters[i].Str) then
    begin
      case CommandData.ParamType of
        ptGeneral:      begin
                          CommandData.ParamType := ptCommandLong;
                          CommandData.Str := LongForm;
                        end;
        ptCommandShort: begin
                          CommandData.ParamType := ptCommandBoth;
                          CommandData.Str := LongForm;
                        end;
      else
       {ptCommandLong,ptCommandBoth - do nothing}
      end;
      For j := Low(fParameters[i].Arguments) to High(fParameters[i].Arguments) do
        AddParamArgument(CommandData,fParameters[i].Arguments[j]);
      Result := True;
    end;
end;

//------------------------------------------------------------------------------

procedure TSCLPParser.Clear;
begin
fCommandLine := '';
fImagePath := '';
SetLength(fParameters,0);
fCount := 0;
fCommandCount := 0;
end;

//------------------------------------------------------------------------------

procedure TSCLPParser.Parse(const CommandLine: String);
var
  LastCmdIdx: Integer;
  i:          Integer;
begin
Clear;
fCommandLine := CommandLine;
TSCLPLexer(fLexer).Analyze(fCommandLine);
LastCmdIdx := -1;
For i := TSCLPLexer(fLexer).LowIndex to TSCLPLexer(fLexer).HighIndex do
  begin
    case TSCLPLexer(fLexer).Tokens[i].TokenType of
      lttGeneral:       begin
                          If CheckIndex(LastCmdIdx) then
                            AddParamArgument(LastCmdIdx,TSCLPLexer(fLexer).Tokens[i].Str);
                          AddParam(ptGeneral,TSCLPLexer(fLexer).Tokens[i].Str);
                        end;
      lttCommandShort:  LastCmdIdx := AddParam(ptCommandShort,TSCLPLexer(fLexer).Tokens[i].Str);
      lttCommandLong:   LastCmdIdx := AddParam(ptCommandLong,TSCLPLexer(fLexer).Tokens[i].Str);
    end;
  end;
If fCount > 0 then
  If First.ParamType = ptGeneral then
    fImagePath := First.Str;
end;

// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

procedure TSCLPParser.Parse;
begin
Parse(GetCommandLine);
end;

end.
