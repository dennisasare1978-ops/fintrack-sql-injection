INSERT INTO CustomerTransactions (CustomerName, CreditCardNumber, CVV, SSN, Balance, TransactionType)
VALUES
    ('Alice Johnson',   '4532015112830366', 123, '000-01-0001', 5234.50,   'PURCHASE'),
    ('Alice Johnson',   '4532015112830366', 123, '000-01-0001', -150.00,   'REFUND'),
    ('Bob Martinez',    '5425233430109903', 456, '000-02-0002', 12890.00,  'DEPOSIT'),
    ('Carol Williams',  '374251018720955',  789, '000-03-0003', 892.25,    'PURCHASE'),
    ('David Chen',      '4916338506082832', 321, '000-04-0004', 45600.00,  'WIRE_TRANSFER'),
    ('Eve Thompson',    '5019717010103742', 654, '000-05-0005', 3200.75,   'PURCHASE'),
    ('Frank Miller',    '6011000990139424', 987, '000-06-0006', 0.01,      'PURCHASE'),
    ('Grace Lee',       '4532015112830366', 234, '000-07-0007', 99999.99,  'DEPOSIT'),
    ('Henry Park',      '5425233430109903', 567, '000-08-0008', -500.00,   'WITHDRAWAL'),
    ('Iris Nguyen',     '374251018720955',  890, '000-09-0009', 7654.32,   'PURCHASE');
GO
