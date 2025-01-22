**free
dcl-s count int(10);
dcl-s note varchar(50);

exec sql SELECT COUNT(*) INTO :count FROM ravi.buildpf;

count += 1;
note = 'Build# ' + %char(count);

count = count;

exec sql INSERT INTO ravi.buildpf (note) VALUES (:note);
eval count = count;
*inlr = *on;  