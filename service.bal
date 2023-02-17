import ballerina/http;

# A service representing a network-accessible API
# bound to port `9090`.
service /readers on new http:Listener(9090) {

    resource function get books() returns BookEntry[] {
        return bookTable.toArray();
    }

    resource function post books(@http:Payload BookEntry[] bookEntries)
                                    returns BookEntry[]|ConflictingISBNCodesError {

        string[] conflictingISBNs = from BookEntry bookEntry in bookEntries
            where bookTable.hasKey(bookEntry.isbn_code)
            select bookEntry.isbn_code;

        if conflictingISBNs.length() > 0 {
            return {
                body: {
                    errmsg: string:'join(" ", "Conflicting ISBN Codes:", ...conflictingISBNs)
                }
            };
        } else {
            foreach var bookEntry in bookEntries {
                bookEntry.isAvailable = true;
                bookTable.add(bookEntry);
            }
            return bookEntries;
        }
    }

    resource function get books/[string isbn_code]() returns BookEntry|InvalidISBNCodeError {
        BookEntry? bookEntry = bookTable[isbn_code];
        if bookEntry is () {
            return {
                body: {
                    errmsg: string `Invalid ISBN Code: ${isbn_code}`
                }
            };
        }
        return bookEntry;
    }

    resource function put books/[string isbn_code]/actions(@http:Payload MemberAction memberAction) returns BookEntry|InvalidISBNCodeError {
        BookEntry? bookEntry = bookTable[isbn_code];
        if bookEntry is () {
            return {
                body: {
                    errmsg: string `Invalid ISBN Code: ${isbn_code}`
                }
            };
        } else {
            if memberAction.action == "borrow" {
                if (!bookEntry.'isAvailable) {
                    return {
                        body: {
                            errmsg: string `Book is not available to borrow: ${isbn_code}`
                        }
                    };
                }

                if (!readers.hasKey(memberAction.memberId) || readers.get(memberAction.memberId).length() == 0) {
                    readers[memberAction.memberId] = {books: [isbn_code]};
                } else  {
                    readers.get(memberAction.memberId).books.push(isbn_code);
                }
                bookEntry.isAvailable = false;
                return bookEntry;
            } else if memberAction.action == "return" {
                if (!readers.hasKey(memberAction.memberId) || readers.get(memberAction.memberId).length() == 0) {
                     return {
                        body: {
                            errmsg: string `Book is not borrowed by : ${memberAction.memberId}`
                        }
                    };
                } else {
                    Reader borrower = readers.get(memberAction.memberId);
                    readers[memberAction.memberId].books = borrower.books.filter(i => i != isbn_code);
                    bookEntry.isAvailable = true;
                    return bookEntry;
                } 
            } else {
                return {
                    body: {
                        errmsg: string `Invalid Action: ${memberAction.action}`
                    }
                };
            }
        }
    }
}

public type BookEntry record {|
    readonly string isbn_code;
    string title;
    string author;
    boolean 'isAvailable;
|};

public type Address record {|
    string city;
    string street;
    string postalcode;
    string locationLink;
|};

public type Reader record {|
    string[] books;
|};

public type MemberAction record {|
    string action;
    string memberId;
|};

public final table<BookEntry> key(isbn_code) bookTable = table [
    {
        isbn_code: "9780743273565",
        title: "The Great Gatsby",
        author: "F. Scott Fitzgerald",
        isAvailable: true
    },
    {
        isbn_code: "9780446310789",
        title: "To Kill a Mockingbird",
        author: "Harper Lee",
        isAvailable: true
    },
    {
        isbn_code: "9780141439518",
        title: "Pride and Prejudice",
        author: "Jane Austen",
        isAvailable: false
    }
];

public final map<Reader> readers = {
    "00001": {books: ["9780141439518"]}
};

public type ConflictingISBNCodesError record {|
    *http:Conflict;
    ErrorMsg body;
|};

public type InvalidISBNCodeError record {|
    *http:NotFound;
    ErrorMsg body;
|};

public type BookIsnotAvailable record {|
    *http:Forbidden;
    ErrorMsg body;
|};

public type ErrorMsg record {|
    string errmsg;
|};


