**free
dcl-s count int(10);
dcl-s note varchar(50);

exec sql SELECT COUNT(*) INTO :count FROM ravi.buildpf;

count += 1;
note = 'Build# ' + %char(count);

exec sql INSERT INTO ravi.buildpf (note) VALUES (:note);

*inlr = *on;